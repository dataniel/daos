#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>
#include <R_ext/Visibility.h>
#include <math.h>
#include <limits.h>
#include <stdint.h>
#include <string.h>

/* Shared normalisation: remove ASCII spaces/dashes, pad exactly nine digits.
   The parser never constructs cleaned R strings. clean_cpr uses the same scan. */
typedef struct {
    int digits[10];
    int valid_format;
    int changed;
    int pad;
} CprScan;

static CprScan scan_cpr(SEXP string) {
    CprScan scan = {{0}, 0, 0, 0};
    if (string == NA_STRING) return scan;
    const unsigned char *s = (const unsigned char *) CHAR(string);
    int count = 0, all_digits = 1;
    for (; *s; ++s) {
        if (*s == ' ' || *s == '-') { scan.changed = 1; continue; }
        if (*s < '0' || *s > '9') all_digits = 0;
        if (count < 10) scan.digits[count] = *s - '0';
        ++count;
    }
    if (!all_digits || (count != 9 && count != 10)) return scan;
    if (count == 9) {
        for (int j = 9; j > 0; --j) scan.digits[j] = scan.digits[j - 1];
        scan.digits[0] = 0;
        scan.pad = scan.changed = 1;
    }
    scan.valid_format = 1;
    return scan;
}

SEXP daos_clean_cpr(SEXP x) {
    if (TYPEOF(x) != STRSXP) Rf_error("Internal error: CPR input must be character.");
    R_xlen_t n = XLENGTH(x);
    SEXP out = x;
    int nprotect = 0;
    char *buffer = NULL;
    size_t capacity = 0;
    for (R_xlen_t i = 0; i < n; ++i) {
        if ((i & 65535) == 0) R_CheckUserInterrupt();
        SEXP string = STRING_ELT(x, i);
        CprScan scan = scan_cpr(string);
        if (!scan.changed) continue;
        if (out == x) {
            out = PROTECT(Rf_duplicate(x));
            ++nprotect;
        }
        size_t required = (size_t)LENGTH(string) + 2;
        if (required > capacity) {
            capacity = required > capacity * 2 ? required : capacity * 2;
            buffer = (char *) R_alloc(capacity, 1);
        }
        const char *s = CHAR(string);
        size_t k = 0;
        if (scan.pad) buffer[k++] = '0';
        for (; *s; ++s) if (*s != ' ' && *s != '-') buffer[k++] = *s;
        SET_STRING_ELT(out, i, Rf_mkCharLenCE(buffer, (int)k, Rf_getCharCE(string)));
    }
    UNPROTECT(nprotect);
    return out;
}

static int valid_date(int y, int m, int d) {
    static const int days[] = {31,28,31,30,31,30,31,31,30,31,30,31};
    if (m < 1 || m > 12 || d < 1) return 0;
    return d <= days[m - 1] + (m == 2 && y % 4 == 0 && (y % 100 != 0 || y % 400 == 0));
}

static double days_from_civil(int y, int m, int d) {
    y -= m <= 2;
    int era = (y >= 0 ? y : y - 399) / 400;
    int yoe = y - era * 400;
    int mp = m + (m > 2 ? -3 : 9);
    int doy = (153 * mp + 2) / 5 + d - 1;
    return era * 146097.0 + yoe * 365 + yoe / 4 - yoe / 100 + doy - 719468;
}

/* Inverse civil-day arithmetic, independent of timezone and strptime. */
static void civil_from_days(double z, double *year, int *md) {
    if (!R_FINITE(z) || fabs(z) > 1e12) { *year = NA_REAL; *md = 0; return; }
    int64_t days = (int64_t)floor(z) + 719468;
    int64_t era = (days >= 0 ? days : days - 146096) / 146097;
    unsigned int doe = (unsigned int)(days - era * 146097);
    unsigned int yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    unsigned int doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    int mp = (int)((5 * doy + 2) / 153);
    int d = (int)doy - (153 * mp + 2) / 5 + 1;
    int m = mp + (mp < 10 ? 3 : -9);
    *year = yoe + era * 400.0 + (m <= 2);
    *md = m * 100 + d;
}

typedef struct {
    const double *value;
    const SEXP *strings;
    int kind;
    int at;
    R_xlen_t length;
    const char *name;
} Reference;

static void read_reference(const Reference *ref, R_xlen_t i, double *year, int *md) {
    R_xlen_t k = ref->length == 1 ? 0 : i;
    if (ref->kind == 0) { *year = ref->value[k]; *md = ref->at; return; }
    if (ref->kind == 1) { civil_from_days(ref->value[k], year, md); return; }
    SEXP string = ref->strings[k];
    if (string == NA_STRING) { *year = NA_REAL; *md = 0; return; }
    const char *s = CHAR(string);
    int digits[8], kdigit = 0;
    int ok = LENGTH(string) == 10;
    if (ok) {
        for (int j = 0; j < 10; ++j) {
            if (j == 4 || j == 7) { if (s[j] != '-') ok = 0; }
            else if (s[j] < '0' || s[j] > '9') { ok = 0; break; }
            else digits[kdigit++] = s[j] - '0';
        }
    }
    int y = 0, m = 0, d = 0;
    if (ok) {
        y = digits[0]*1000 + digits[1]*100 + digits[2]*10 + digits[3];
        m = digits[4]*10 + digits[5]; d = digits[6]*10 + digits[7];
        ok = valid_date(y, m, d);
    }
    if (!ok) Rf_error("date for `%s` must contain valid ISO dates (YYYY-MM-DD).", ref->name);
    *year = y; *md = m*100 + d;
}

/* codes: 0 bday, 1 age, 2 sex, 3 mod11, 4 valid. One CPR scan per row. */
SEXP daos_cpr_info(SEXP x, SEXP codes, SEXP references) {
    if (TYPEOF(x) != STRSXP || TYPEOF(codes) != INTSXP || TYPEOF(references) != VECSXP)
        Rf_error("Internal error: invalid CPR arguments.");
    R_xlen_t n = XLENGTH(x);
    int p = Rf_length(codes);
    const int *type = INTEGER(codes);
    SEXP out = PROTECT(Rf_allocVector(VECSXP, p));
    int **ints = (int **) R_alloc(p, sizeof(int *));
    double **reals = (double **) R_alloc(p, sizeof(double *));
    Reference *refs = (Reference *) R_alloc(p, sizeof(Reference));
    double *scalar_year = (double *) R_alloc(p, sizeof(double));
    int *scalar_md = (int *) R_alloc(p, sizeof(int));
    int need_calendar = 0, need_checksum = 0, need_bday = 0;
    for (int j = 0; j < p; ++j) {
        int code = type[j];
        if (code < 0 || code > 4) Rf_error("Internal error: unknown CPR output.");
        need_calendar |= code != 3; need_checksum |= code == 3; need_bday |= code == 0;
        SEXP col = PROTECT(Rf_allocVector(code == 0 ? REALSXP : (code >= 3 ? LGLSXP : INTSXP), n));
        if (code == 0) {
            SEXP cls = PROTECT(Rf_mkString("Date"));
            Rf_setAttrib(col, R_ClassSymbol, cls);
            UNPROTECT(1);
            reals[j] = REAL(col);
        } else ints[j] = code >= 3 ? LOGICAL(col) : INTEGER(col);
        SET_VECTOR_ELT(out, j, col);
        UNPROTECT(1);
        if (code == 1) {
            SEXP spec = VECTOR_ELT(references, j);
            SEXP value = VECTOR_ELT(spec, 0);
            refs[j].kind = Rf_asInteger(VECTOR_ELT(spec, 1));
            refs[j].at = Rf_asInteger(VECTOR_ELT(spec, 2));
            refs[j].name = CHAR(STRING_ELT(VECTOR_ELT(spec, 3), 0));
            refs[j].length = XLENGTH(value);
            if (refs[j].length != 1 && refs[j].length != n) Rf_error("Internal error: reference length mismatch.");
            if (refs[j].kind == 2) refs[j].strings = STRING_PTR_RO(value);
            else refs[j].value = REAL(value);
            if (refs[j].length == 1) read_reference(&refs[j], 0, &scalar_year[j], &scalar_md[j]);
        }
    }
    static const int weights[] = {4,3,2,7,6,5,4,3,2,1};
    for (R_xlen_t i = 0; i < n; ++i) {
        if ((i & 65535) == 0) R_CheckUserInterrupt();
        CprScan scan = scan_cpr(STRING_ELT(x, i));
        int valid = 0, y = 0, m = 0, d = 0, checksum = NA_LOGICAL;
        double bday = NA_REAL;
        if (scan.valid_format) {
            const int *v = scan.digits;
            if (need_calendar) {
                d = v[0]*10 + v[1]; m = v[2]*10 + v[3];
                int yy = v[4]*10 + v[5], century = 1900;
                if ((v[6] == 4 || v[6] == 9) && yy <= 36) century = 2000;
                if (v[6] >= 5 && v[6] <= 8) century = yy <= 57 ? 2000 : 1800;
                y = century + yy; valid = valid_date(y, m, d);
                if (valid && need_bday) bday = days_from_civil(y, m, d);
            }
            if (need_checksum) {
                int sum = 0;
                for (int k = 0; k < 10; ++k) sum += v[k] * weights[k];
                checksum = sum % 11 == 0;
            }
        }
        for (int j = 0; j < p; ++j) {
            switch (type[j]) {
                case 0: reals[j][i] = bday; break;
                case 1: {
                    double ry; int md;
                    if (refs[j].length == 1) { ry = scalar_year[j]; md = scalar_md[j]; }
                    else read_reference(&refs[j], i, &ry, &md);
                    double a = ry - y - (md < m*100 + d);
                    ints[j][i] = valid && R_FINITE(a) && a > INT_MIN && a <= INT_MAX ? (int)a : NA_INTEGER;
                    break;
                }
                case 2: ints[j][i] = valid ? scan.digits[9] % 2 : NA_INTEGER; break;
                case 3: ints[j][i] = checksum; break;
                case 4: ints[j][i] = valid; break;
            }
        }
    }
    UNPROTECT(1);
    return out;
}

static const R_CallMethodDef call_methods[] = {
    {"daos_clean_cpr", (DL_FUNC) &daos_clean_cpr, 1},
    {"daos_cpr_info", (DL_FUNC) &daos_cpr_info, 3},
    {NULL, NULL, 0}
};

void attribute_visible R_init_daos(DllInfo *dll) {
    R_registerRoutines(dll, NULL, call_methods, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
    R_forceSymbols(dll, TRUE);
}
