# Shared presentation for the screening app; no additional runtime dependencies.
screen_ts_head <- function() {
  shiny::tags$head(
    shiny::tags$link(rel = "stylesheet",
      href = "https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap"),
    shiny::tags$style(shiny::HTML("
      :root { --screen-ink: #202024; --screen-muted: #67676f;
        --screen-border: #e4e4e8; --screen-accent: #5550cb; }
      body { font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
        background: #f7f7f8; color: var(--screen-ink); margin: 0;
        -webkit-font-smoothing: antialiased; }
      .container-fluid { max-width: 1600px; margin: 0 auto; padding: 18px 24px;
        height: 100vh; height: 100dvh; display: flex; flex-direction: column; }
      .header { display: flex; align-items: center; justify-content: space-between;
        gap: 24px; margin-bottom: 16px; flex-shrink: 0; }
      .header-eyebrow { font-size: 11px; font-weight: 600; color: var(--screen-muted);
        letter-spacing: .1em; text-transform: uppercase; margin-bottom: 6px; }
      .header-title { font-size: 23px; line-height: 1.3; font-weight: 600;
        letter-spacing: -.035em; margin: 0; overflow-wrap: anywhere; }
      .header-actions { display: flex; align-items: center; gap: 16px; flex-shrink: 0; }
      .flag-count { font-size: 12px; color: var(--screen-muted);
        font-variant-numeric: tabular-nums; }
      .screen-btn { display: inline-flex; align-items: center; justify-content: center;
        gap: 10px; min-height: 38px; padding: 8px 12px; border: 1px solid var(--screen-border);
        border-radius: 8px; background: white; color: var(--screen-ink);
        font: inherit; font-size: 12px; line-height: 20px; font-weight: 500;
        white-space: nowrap; box-shadow: 0 1px 2px rgba(24,24,27,.025);
        transition: background .15s, border-color .15s, box-shadow .15s; }
      .screen-btn:hover, .screen-btn:focus { color: var(--screen-ink);
        background: #f4f4f6; border-color: #c9c9d0; }
      .screen-btn:focus-visible, .diagnostic-tools input:focus-visible {
        outline: 3px solid #c9c6fa; outline-offset: 3px; }
      .screen-btn:disabled { opacity: .4; cursor: not-allowed; box-shadow: none; }
      .screen-btn:disabled:hover { background: white; border-color: var(--screen-border); }
      .screen-btn kbd, .diagnostic-tools kbd { font-family: inherit; font-size: 10px; font-weight: 500;
        color: var(--screen-muted); background: #f7f7f9; border: 1px solid var(--screen-border);
        border-radius: 4px; box-shadow: none; padding: 0 5px; min-width: 20px; line-height: 19px; }
      .screen-btn-primary { background: #27272d; border-color: #27272d; color: white; }
      .screen-btn-primary:hover, .screen-btn-primary:focus { background: #3b3b44;
        border-color: #3b3b44; color: white; }
      .screen-btn-primary kbd { background: #404048; border-color: #575761; color: #eeeef1; }
      .control-bar { display: flex; align-items: flex-end; flex-wrap: wrap; gap: 20px;
        padding: 14px 16px; flex-shrink: 0; background: white; border: 1px solid var(--screen-border);
        border-radius: 12px; margin-bottom: 12px; box-shadow: 0 2px 4px rgba(24,24,27,.025); }
      .nav-field { flex-shrink: 0; }
      .nav-group { display: flex; align-items: center; gap: 4px; height: 38px;
        padding: 3px; border: 1px solid var(--screen-border); border-radius: 8px; background: #fafafa; }
      .nav-btn { width: 32px; min-height: 30px; height: 30px; padding: 0;
        font-size: 17px; border-color: transparent; box-shadow: none; background: transparent; }
      .counter { min-width: 76px; padding: 0 8px; text-align: center;
        font-size: 12px; font-weight: 500; color: #52525b; font-variant-numeric: tabular-nums; }
      .group-fields { display: flex; flex: 1; flex-wrap: wrap; gap: 12px; min-width: 160px; }
      .field { display: flex; flex-direction: column; gap: 7px; min-width: 140px; }
      .group-fields > .field { flex: 1 1 160px; min-width: 140px; }
      .field-label { font-size: 11px; font-weight: 500; color: var(--screen-muted);
        margin: 0; line-height: 15px; }
      .field .form-group, .field .selectize-control { margin: 0; }
      .field .form-control, .field .selectize-input, .diagnostic-controls .form-control {
        background: white; border-radius: 7px; border: 1px solid #dcdce2;
        min-height: 38px; font-size: 13px; color: var(--screen-ink);
        font-family: inherit; font-weight: 400; box-shadow: none; }
      .field .form-control { height: 38px; padding: 0 10px; }
      .field .selectize-control.form-control { height: auto; min-height: 0; padding: 0;
        border: 0; background: transparent; box-shadow: none; }
      .field .selectize-dropdown.form-control { height: auto; padding: 0; }
      .field .selectize-input { display: flex; align-items: center; padding: 8px 30px 8px 11px; }
      .field .selectize-input > .item { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
      .field .form-control:focus, .field .selectize-input.focus,
      .diagnostic-controls .form-control:focus { border-color: #8e89dd;
        box-shadow: 0 0 0 3px rgba(85,80,203,.1); outline: none; }
      .selectize-dropdown { font-family: inherit; font-size: 13px; border-color: var(--screen-border);
        border-radius: 7px; overflow: hidden; box-shadow: 0 6px 20px rgba(24,24,27,.08); }
      .selectize-dropdown .option { padding: 9px 11px; }
      .selectize-dropdown .active { background: #f0effb; color: #383486; }
      .flag-btn { min-width: 145px; }
      .flag-btn .flag-icon { color: #8a8a94; font-size: 15px; }
      .flag-btn.active { background: #fffbeb; border-color: #e8c26a; color: #805500; box-shadow: none; }
      .flag-btn.active .flag-icon { color: #b5790b; }
      .flag-btn.active kbd { background: #fff7d6; border-color: #ecd79e; color: #805500; }
      .screen-workspace { display: grid; grid-template-columns: minmax(0, 1fr) 248px;
        align-items: stretch; gap: 18px; flex: 1; min-height: 0; }
      .screen-main, .screen-sidebar { min-width: 0; min-height: 0; }
      .screen-main { display: flex; flex-direction: column; }
      .screen-sidebar { overflow-y: auto; scrollbar-width: thin; }
      .diagnostic-tools, .scope-tools { padding: 18px 16px; background: white;
        border: 1px solid var(--screen-border); border-radius: 12px; }
      .scope-tools { margin-bottom: 12px; }
      .screen-sidebar summary { display: flex; align-items: center; justify-content: space-between;
        gap: 12px; cursor: pointer; list-style: none; font-size: 13px; font-weight: 600; }
      .screen-sidebar summary::-webkit-details-marker { display: none; }
      .sidebar-chevron { color: #8b8b96; font-size: 17px; transform: rotate(-90deg); }
      details[open] > summary .sidebar-chevron { transform: none; }
      .sidebar-intro { margin: 9px 0 16px; color: var(--screen-muted); font-size: 11px; line-height: 1.6; }
      .scope-caption { display: block; color: var(--screen-muted); font-size: 11px; font-weight: 400; margin-top: 5px; }
      .scope-body .field { min-width: 0; margin-bottom: 14px; }
      .scope-body .shiny-input-container { width: 100%; }
      .scope-body label { font-size: 11px; font-weight: 500; color: var(--screen-muted); }
      .scope-body .selectize-input { flex-wrap: wrap; min-height: 38px; padding: 6px 8px; gap: 4px; }
      .scope-body .selectize-input > .item { margin: 0; max-width: 100%; font-size: 11px; }
      .scope-reset { width: 100%; margin: 8px 0; }
      .irs--shiny .irs-bar { background: var(--screen-accent); border-color: var(--screen-accent); }
      .diagnostic-tools .shiny-input-container { width: auto; }
      .diagnostic-tools .shiny-input-checkboxgroup { margin: 0; }
      .diagnostic-tools .shiny-options-group { display: flex; flex-direction: column; gap: 6px; }
      .diagnostic-tools .checkbox-inline { display: flex; align-items: center; gap: 9px;
        margin: 0; padding: 10px 9px; border: 1px solid transparent; border-radius: 7px;
        font-size: 12px; line-height: 18px; color: #41414a; background: #fafafa;
        transition: border-color .15s, background .15s; }
      .diagnostic-tools .checkbox-inline:hover { border-color: #d7d4ed; background: #f7f6fe; }
      .diagnostic-tools .checkbox-inline:has(input:checked) { color: #48429d;
        background: #f0effb; border-color: #d5d1f3; }
      .diagnostic-tools .checkbox-inline input { position: static; margin: 0; width: 13px;
        height: 13px; accent-color: var(--screen-accent); flex-shrink: 0; }
      .diagnostic-tools .checkbox-inline > span { display: flex; flex: 1; min-width: 0;
        align-items: center; justify-content: space-between; gap: 7px; }
      .tool-copy { display: flex; flex-direction: column; }
      .tool-description { color: var(--screen-muted); font-size: 10px; line-height: 1.5; }
      .diagnostic-tools kbd { text-align: center; flex-shrink: 0; }
      .diagnostic-controls { padding-top: 16px; margin-top: 16px; border-top: 1px solid #eeeef1; }
      .diagnostic-controls .form-group { width: 100%; max-width: 100%; margin-bottom: 10px; }
      .diagnostic-controls label { font-size: 11px; color: var(--screen-muted); font-weight: 500; }
      .diagnostic-controls .selectize-control.form-control { padding: 0; border: 0; min-height: 0; height: auto; box-shadow: none; }
      .diagnostic-controls .selectize-input { border-radius: 7px; box-shadow: none; min-height: 36px; font-size: 12px; }
      .diagnostic-context { font-size: 10px; color: var(--screen-muted); padding-top: 10px; line-height: 1.8; }
      .field-help { font-size: 10px; line-height: 1.6; color: var(--screen-muted); margin: 6px 0 12px; }
      .screen-plot-card { background: white; border: 1px solid var(--screen-border);
        display: flex; flex-direction: column; flex: 1; min-height: 0;
        border-radius: 12px; padding: 14px 20px; box-shadow: 0 2px 4px rgba(24,24,27,.025); }
      .plot-meta { display: flex; align-items: center; flex-wrap: wrap; gap: 18px;
        flex-shrink: 0; margin-bottom: 4px; padding-bottom: 10px; border-bottom: 1px solid #eeeef1; }
      .plot-meta-left { flex: 1 1 220px; min-width: 0; }
      .plot-title { font-size: 17px; line-height: 1.5; font-weight: 600;
        letter-spacing: -.02em; margin: 0; overflow-wrap: anywhere; }
      .plot-subtitle { font-size: 12px; color: var(--screen-muted); margin-top: 3px; }
      .y-axis-controls { display: flex; align-items: flex-end; flex-wrap: wrap; gap: 10px; }
      .y-axis-controls .field { min-width: 70px; width: 78px; }
      .y-axis-controls .form-control { font-size: 12px; }
      .field .form-control::placeholder { color: #898992; opacity: 1; }
      .plot-area { flex: 1; min-height: 160px; position: relative; }
      .plot-area > .plotly { height: 100% !important; }
      .diagnostic-dock { flex-shrink: 0; position: relative; border-top: 1px solid #eaeaf0; padding-top: 4px; }
      .diagnostic-dock .nav-tabs { display: flex; flex-wrap: wrap; padding-right: 96px; border-bottom: 1px solid #eeeef1; }
      .diagnostic-dock .nav-tabs::before, .diagnostic-dock .nav-tabs::after { display: none; }
      .diagnostic-dock .nav-tabs > li { margin: 0; float: none; }
      .diagnostic-dock .nav-tabs > li > a { margin: 0 12px 0 0; padding: 10px 0; border: 0;
        border-bottom: 2px solid transparent; border-radius: 0; color: var(--screen-muted); font-size: 11px; }
      .diagnostic-dock .nav-tabs > li > a:hover { background: transparent; color: var(--screen-accent); }
      .diagnostic-dock .nav-tabs > li.active > a,
      .diagnostic-dock .nav-tabs > li.active > a:focus,
      .diagnostic-dock .nav-tabs > li.active > a:hover { border: 0; border-bottom: 2px solid var(--screen-accent);
        color: var(--screen-accent); background: transparent; font-weight: 600; }
      .diagnostic-dock .tab-content { min-height: clamp(200px, 24vh, 240px); padding-top: 12px; }
      .diagnostic-dock .tab-pane { min-height: clamp(188px, calc(24vh - 12px), 228px); }
      .link-btn { border: 0; border-radius: 4px; padding: 5px 0; background: transparent;
        font: inherit; font-size: 10px; color: var(--screen-accent); cursor: pointer; }
      .link-btn:hover { color: #383486; text-decoration: underline; }
      .dock-notes { position: absolute; right: 0; top: 11px; padding: 4px; }
      .analysis-layout { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 2fr); gap: 20px; min-height: inherit; }
      .analysis-finding, .analysis-detail { min-width: 0; min-height: 0; }
      .analysis-finding > .shiny-html-output + .shiny-html-output { margin-top: 10px; }
      .analysis-chart { height: clamp(188px, calc(24vh - 12px), 228px); min-height: 0; }
      .analysis-chart > .plotly { height: 100% !important; }
      .analysis-detail { padding-left: 20px; border-left: 1px solid #eeeef1; }
      .insight-link { position: relative; text-align: left; font: inherit; cursor: pointer; }
      .insight-link:hover { border-color: #a8a2dc; }
      .insight-link strong { display: block; font-size: 12px; line-height: 1.45; margin-top: 4px; padding-right: 10px; font-weight: 600; }
      .insight-arrow { position: absolute; right: 10px; top: 10px; font-size: 13px; color: #96929f; }
      .insight-link:focus-visible, .link-btn:focus-visible, .nav-tabs a:focus-visible {
        outline: 3px solid #c9c6fa; outline-offset: 2px; }
      .notes-content { font-size: 12px; line-height: 1.8; }
      .notes-content ul { padding-left: 18px; }
      .notes-content li + li { margin-top: 10px; }
      .modal-content { border-radius: 12px; border-color: var(--screen-border); }
      .modal-body { max-height: 70vh; overflow: auto; }
      .modal-title { font-size: 17px; }
      .insights-heading { display: flex; align-items: center; flex-wrap: wrap; gap: 10px; margin-bottom: 10px; }
      .insights-heading h3 { margin: 0; font-size: 13px; font-weight: 600; }
      .series-badge { padding: 3px 8px; border-radius: 5px; background: #f3f2fa; font-size: 10px;
        color: #645e93; overflow-wrap: anywhere; max-width: 100%; }
      .insights-grid { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 8px; }
      .insight { padding: 10px 12px; border: 1px solid #e9e9ef; border-left: 3px solid #c5c5d0;
        border-radius: 7px; background: #fafafb; }
      .insight-tool { font-size: 10px; font-weight: 500; color: var(--screen-muted); }
      .insight h4 { font-size: 13px; line-height: 1.45; font-weight: 600; margin: 4px 0 5px; }
      .insight p { font-size: 11px; line-height: 1.65; color: #676772; margin: 0; }
      .insight-attention { border-left-color: #c59132; background: #fffcf4; }
      .insight-pattern { border-left-color: #8982d7; background: #f8f7ff; }
      .insight-unavailable { border-left-color: #b6b6be; background: #f7f7f8; }
      .sample-period { display: flex; flex-wrap: wrap; gap: 4px 12px; justify-content: space-between;
        font-size: 10px; color: var(--screen-muted); padding-bottom: 8px; }
      .metric-grid { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 8px; }
      .metric { display: flex; flex-direction: column; align-items: flex-start; gap: 5px; padding: 9px;
        background: #f8f8fb; border: 1px solid #eeeef3; border-radius: 8px; min-width: 0; }
      .metric-label { font-size: 10px; color: var(--screen-muted); }
      .metric-value { font-size: 19px; line-height: 1.2; font-weight: 600; letter-spacing: -.035em;
        font-variant-numeric: tabular-nums; overflow-wrap: anywhere; }
      .metric-detail { font-size: 10px; color: var(--screen-muted); line-height: 1.5; }
      .detail-label { display: flex; align-items: center; justify-content: space-between;
        font-size: 10px; font-weight: 500; color: var(--screen-muted); margin: 8px 0 6px; }
      .detail-label .link-btn { padding: 0; }
      .distribution-strip { display: grid; grid-template-columns: repeat(5, minmax(0, 1fr)); gap: 4px;
        padding: 8px 0; border-top: 1px solid #ededf2; border-bottom: 1px solid #ededf2; }
      .distribution-strip > div { display: flex; flex-direction: column; gap: 7px; min-width: 0; }
      .distribution-strip span { font-size: 9px; color: var(--screen-muted); }
      .distribution-strip strong { font-size: 11px; font-weight: 500; font-variant-numeric: tabular-nums; overflow-wrap: anywhere; }
      .result-disclosure { margin-top: 14px; }
      .result-disclosure summary, .method-notes summary { font-size: 11px; font-weight: 500; cursor: pointer; color: #575761; }
      .disclosure-hint { color: #888892; font-size: 10px; font-weight: 400; margin-left: 8px; }
      .quality-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 8px; margin-top: 14px; }
      .quality-item { display: flex; align-items: center; justify-content: space-between; gap: 8px;
        font-size: 10px; color: var(--screen-muted); padding: 8px 0; border-bottom: 1px solid #eeeef3; }
      .quality-item strong { color: #46464f; font-weight: 500; font-variant-numeric: tabular-nums; }
      .quality-item.has-issue strong { color: #9b6c16; }
      .strength-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 20px; }
      .strength > div { display: flex; justify-content: space-between; align-items: baseline; gap: 8px; font-size: 10px; color: var(--screen-muted); }
      .strength strong { font-size: 16px; color: #5550a1; font-weight: 600; }
      .strength meter { display: block; width: 100%; height: 13px; margin-top: 5px; }
      .strength meter::-webkit-meter-bar { background: #eeeef6; border: 0; border-radius: 3px; }
      .strength meter::-webkit-meter-optimum-value { background: #8882db; border-radius: 3px; }
      .strength meter::-moz-meter-bar { background: #8882db; }
      .result-footnote { font-size: 10px; line-height: 1.65; color: var(--screen-muted); margin: 12px 0 0; }
      .result-count { display: flex; align-items: baseline; gap: 10px; margin-bottom: 6px; }
      .result-count strong { font-size: 20px; font-weight: 600; letter-spacing: -.035em; }
      .result-count span { font-size: 11px; color: var(--screen-muted); }
      .result-empty { padding: 18px 14px; background: #f8f8fa; border-radius: 8px; }
      .result-empty strong { font-size: 12px; font-weight: 500; }
      .result-empty p { margin: 7px 0 0; font-size: 11px; line-height: 1.7; color: var(--screen-muted); }
      .result-table-scroll { overflow-x: auto; }
      .result-table { width: 100%; font-size: 11px; }
      .result-table th { background: #f8f8fb; font-size: 10px; font-weight: 500; color: var(--screen-muted); }
      .result-table th, .result-table td { padding: 7px 8px; border-bottom: 1px solid #eeeef3; }
      .result-table td { font-variant-numeric: tabular-nums; }
      .result-table th:not(:first-child), .result-table td:not(:first-child) { text-align: right; }
      .test-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px; }
      .test-result { padding: 12px; border: 1px solid #ededf2; border-radius: 8px; background: #fafafb; }
      .test-heading { display: flex; align-items: center; flex-wrap: wrap; gap: 6px; justify-content: space-between; }
      .test-heading h4 { margin: 0; font-size: 12px; font-weight: 500; }
      .test-pvalue { background: #f1f0fa; padding: 4px 7px; border-radius: 5px; font-size: 11px; color: #635d9e; }
      .test-conclusion { font-size: 12px; font-weight: 500; line-height: 1.6; margin: 10px 0 7px; }
      .test-assumption { display: flex; flex-direction: column; gap: 4px; font-size: 10px; color: var(--screen-muted); }
      .correlation-metrics { grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 6px; }
      .correlation-metrics .metric { padding: 7px; }
      .correlation-metrics .metric-value { font-size: 15px; }
      .correlation-metrics .metric-label { font-size: 9px; }
      .method-notes { margin-top: 18px; padding: 16px 20px; background: #f2f2f5; border-radius: 8px; }
      .method-notes ul { font-size: 11px; line-height: 1.8; color: var(--screen-muted); margin: 14px 0 0; padding-left: 17px; }
      .method-notes li + li { margin-top: 7px; }
      .shiny-output-error-validation { color: var(--screen-muted); font-size: 13px; padding: 18px 0; }
      summary:focus-visible { outline: 3px solid #c9c6fa; outline-offset: 4px; }
      @media (max-width: 1100px) { .screen-workspace { grid-template-columns: minmax(0, 1fr) 218px; gap: 14px; }
        .analysis-layout { gap: 12px; }
        .analysis-detail { padding-left: 12px; }
        .diagnostic-dock .nav-tabs > li > a { font-size: 10px; margin-right: 9px; } }
      @media (max-width: 900px), (max-height: 680px) {
        .container-fluid { height: auto; min-height: 100vh; }
        .screen-workspace { flex: none; }
        .plot-area { flex: none; height: 360px; }
        .screen-sidebar { max-height: none; overflow: visible; }
        .diagnostic-dock .tab-content { height: auto; min-height: 200px; }
        .analysis-chart { height: 220px; }
      }
      @media (max-width: 900px) { .screen-workspace { display: flex; flex-direction: column; }
        .screen-main, .screen-sidebar { width: 100%; }
        .screen-sidebar { position: static; max-height: none; overflow: visible; order: -1; }
        .scope-tools { margin-bottom: 10px; }
        .diagnostic-tools .shiny-options-group { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); }
        .diagnostic-controls { display: flex; flex-wrap: wrap; gap: 12px; }
        .diagnostic-controls .form-group { width: 210px; } }
      @media (max-width: 700px) { .container-fluid { padding: 20px 16px; }
        .header { align-items: flex-start; gap: 16px; }
        .header-title { font-size: 20px; }
        .header-actions { flex-direction: column-reverse; align-items: flex-end; gap: 6px; }
        .control-bar { padding: 16px; gap: 16px; }
        .group-fields { flex-basis: 100%; order: 3; }
        .flag-btn { margin-left: auto; }
        .screen-plot-card { padding: 18px 14px 12px; }
        .plot-meta-left { flex-basis: 100%; }
        .y-axis-controls { width: 100%; }
        .y-axis-controls .screen-btn { margin-left: auto; }
        .insights-grid { grid-template-columns: minmax(0, 1fr); }
        .analysis-layout { grid-template-columns: minmax(0, 1fr); }
        .analysis-detail { border: 0; padding: 0; }
        .metric-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
        .correlation-metrics { grid-template-columns: repeat(3, minmax(0, 1fr)); }
        .test-grid { grid-template-columns: minmax(0, 1fr); }
        .diagnostic-dock .nav-tabs { padding-right: 0; }
        .dock-notes { position: static; display: block; margin-left: auto; }
        .insights-heading { margin-top: 4px; }
        .diagnostic-tools .shiny-options-group { grid-template-columns: minmax(0, 1fr); } }
      @media (prefers-reduced-motion: reduce) { .screen-btn, .checkbox-inline { transition: none; } }
    ")),
    shiny::tags$script(shiny::HTML("
      $(function() {
        if (window.matchMedia('(max-width: 900px)').matches) $('#diagnostic-panel').prop('open', false);
        $('#diagnostics input[type=checkbox]').each(function(i) {
          $(this).attr('aria-keyshortcuts', String(i + 1));
        });
        // Plotly must follow the available space when the integrated panel opens.
        var resizePending = false;
        function resizePlots() {
          if (resizePending) return;
          resizePending = true;
          requestAnimationFrame(function() {
            resizePending = false;
            $('.plot-area > .plotly, .analysis-chart > .plotly').each(function() {
              if (this.data && $(this).is(':visible') && window.Plotly) Plotly.Plots.resize(this);
            });
          });
        }
        if (window.ResizeObserver) {
          var observer = new ResizeObserver(resizePlots);
          $('.plot-area, .analysis-chart').each(function() { observer.observe(this); });
        }
        $(document).on('shown.bs.tab', resizePlots);
        $(document).on('click', '[data-diagnostic-tab]', function() {
          var value = $(this).attr('data-diagnostic-tab');
          $('#diagnostic_view a[data-value]').filter(function() {
            return $(this).attr('data-value') === value;
          }).tab('show');
        });
      });
      $(document).on('keydown.screening', function(e) {
        if ($('.modal.in, .modal.show').length) return;
        var focusedTab = $(e.target).closest('#diagnostic_view a');
        if (focusedTab.length && ['ArrowLeft', 'ArrowRight', 'Home', 'End'].indexOf(e.key) >= 0) {
          e.preventDefault();
          var tabs = $('#diagnostic_view a:visible');
          var index = tabs.index(focusedTab);
          index = e.key === 'Home' ? 0 : e.key === 'End' ? tabs.length - 1 :
            (index + (e.key === 'ArrowRight' ? 1 : -1) + tabs.length) % tabs.length;
          tabs.eq(index).tab('show').trigger('focus');
          return;
        }
        var editable = $(e.target).closest('textarea, select, input:not([type=checkbox]):not([type=radio]):not([type=button]):not([type=submit]), [contenteditable]:not([contenteditable=false]), [role=combobox], [role=slider], .irs').length;
        if (e.key === 'Escape') {
          if (editable) e.target.blur();
          return;
        }
        if (editable || e.ctrlKey || e.metaKey || e.altKey ||
            (e.originalEvent && e.originalEvent.isComposing)) return;
        if (/^[1-6]$/.test(e.key)) {
          e.preventDefault();
          if (e.repeat || (e.originalEvent && e.originalEvent.repeat)) return;
          var checkbox = $('#diagnostics input[type=checkbox]').eq(Number(e.key) - 1);
          checkbox.prop('checked', !checkbox.prop('checked')).trigger('change');
          return;
        }
        // Keep native Space activation on focused buttons, checkboxes and links.
        if (e.key === ' ' && $(e.target).closest('button, a, summary, input[type=checkbox], input[type=radio], [role=button]').length) return;
        var target = { ArrowLeft: '#prev', ArrowRight: '#next_btn', ' ': '#flag_btn',
          r: '#reset_zoom', R: '#reset_zoom', q: '#finish_btn', Q: '#finish_btn' }[e.key];
        if (!target) return;
        e.preventDefault();
        if ((e.repeat || (e.originalEvent && e.originalEvent.repeat)) &&
            e.key !== 'ArrowLeft' && e.key !== 'ArrowRight') return;
        if (!$(target).prop('disabled')) $(target).trigger('click');
      });
      Shiny.addCustomMessageHandler('screen_state', function(msg) {
        $('#prev').prop('disabled', msg.first);
        $('#next_btn').prop('disabled', msg.last);
        $('#flag_btn').prop('disabled', msg.empty);
        $('#flag_btn').toggleClass('active', msg.flagged).attr('aria-pressed', String(msg.flagged))
          .attr('title', msg.flagged ? 'Remove flag (Space)' : 'Flag this group (Space)');
        $('#flag_btn .button-label').text(msg.flagged ? 'Flagged' : 'Flag group');
      });
    "))
  )
}

screen_ts_button <- function(id, label, shortcut, class = "", ...) {
  shiny::actionButton(id, shiny::tagList(
    shiny::span(class = "button-label", label),
    shiny::tags$kbd(`aria-hidden` = "true", shortcut)
  ), class = paste("screen-btn", class), ...)
}
