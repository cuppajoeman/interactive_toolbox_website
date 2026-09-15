#scope_module

GL :: #import "GL";
using GL;

Renderer :: #import "tbx/web/Generated_Vertex_Color_Renderer";
using Renderer;

UI :: #import "tbx/ui";
UI_Renderer :: #import "tbx/web/WebGL_UI_Renderer";
Asset_Bridge :: #import "tbx/web/Web_Asset_Bridge";
Web :: #import "tbx/web";

Math :: #import "Math";
using Math;

#scope_export

Website_Page :: enum s32 {
    HOME;
    JAIDE;
}

Interactive_Toolbox_Program :: struct {
    renderer: WebGL_Camera_Per_Object_Transform_Color_Renderer;
    ui_renderer: UI_Renderer.WebGL_UI_Renderer;
    ui_context: UI.UI_Context;
    ui_font: UI.MSDF_Font;
    torus: WebGL_Renderable;

    viewport_width: s32 = 1;
    viewport_height: s32 = 1;
    previous_frame_time: float;
    selected_page: s32 = cast(s32) Website_Page.HOME;
    jaide_section: s32;

    mouse_x: float32;
    mouse_y: float32;
    mouse_left_down: bool;
    mouse_right_down: bool;
    mouse_scroll_y: float32;
}

website_program: Interactive_Toolbox_Program;

main :: () {
    Web.install_runtime_context(*context);
    init(*website_program);
    print("Interactive Toolbox website initialized.\n");
}

#program_export
draw_frame :: (time_seconds: float) {
    render_frame(*website_program, time_seconds);
    reset_temporary_storage();
}

#program_export
resize :: (width: s32, height: s32) #no_context {
    if width < 1 width = 1;
    if height < 1 height = 1;
    website_program.viewport_width = width;
    website_program.viewport_height = height;
    glViewport(0, 0, width, height);
}

#program_export
set_msdf_atlas_texture_input :: (texture_gl_handle: u32) #no_context {
    website_program.ui_font.texture_handle = cast(UI.UI_Texture_Handle) texture_gl_handle;
}

#program_export
ui_pointer_input :: (x: float32, y: float32, left_down: bool, right_down: bool) #no_context {
    website_program.mouse_x = x;
    website_program.mouse_y = y;
    website_program.mouse_left_down = left_down;
    website_program.mouse_right_down = right_down;
}

#program_export
ui_scroll_input :: (scroll_y: float32) #no_context {
    website_program.mouse_scroll_y += scroll_y;
}

#program_export
set_selected_page_input :: (page: s32) #no_context {
    if page < 0 || page > 1 return;
    website_program.selected_page = page;
}

init :: (program: *Interactive_Toolbox_Program) {
    assert(Asset_Bridge.init_web_asset_package(), "Could not initialize browser asset package.");
    program.ui_font = UI.load_msdf_font_metrics("fonts/pt_mono/atlas.json");
    UI.ui_init(*program.ui_context, *program.ui_font);
    configure_site_style(*program.ui_context.style);

    Renderer.init(*program.renderer);
    UI_Renderer.init(*program.ui_renderer);

    torus_geometry := create_torus_geometry(1.45, 0.48, 72, 30);
    Renderer.buffer_object(*program.renderer, *program.torus, *torus_geometry);
    program.torus.position = .{0.0, -0.28, 0.0};
    program.torus.scale = 1.18;
    array_free(torus_geometry.vertices);
    array_free(torus_geometry.indices);

    glEnable(GL_DEPTH_TEST);
    glEnable(GL_CULL_FACE);
    glCullFace(GL_BACK);
    glFrontFace(GL_CCW);
    glClearColor(0.018, 0.024, 0.040, 1.0);
}

configure_site_style :: (style: *UI.UI_Style) {
    style.color_bg              = .{0.060, 0.078, 0.115, 1.0};
    style.color_bg_hover        = .{0.115, 0.150, 0.205, 1.0};
    style.color_bg_active       = .{0.155, 0.205, 0.275, 1.0};
    style.color_border          = .{0.210, 0.275, 0.360, 1.0};
    style.color_text            = .{0.940, 0.960, 0.990, 1.0};
    style.color_text_disabled   = .{0.555, 0.630, 0.725, 1.0};
    style.color_accent          = .{0.165, 0.780, 0.680, 1.0};
    style.color_accent_hover    = .{0.235, 0.875, 0.765, 1.0};
    style.color_accent_active   = .{0.100, 0.620, 0.545, 1.0};
    style.color_slider_track    = .{0.035, 0.048, 0.075, 1.0};
    style.color_slider_grab     = .{0.245, 0.865, 0.755, 1.0};
    style.color_panel_bg        = .{0.030, 0.043, 0.070, 0.955};
    style.color_separator       = .{0.160, 0.215, 0.285, 1.0};
    style.color_scrollbar_bg    = .{0.025, 0.035, 0.055, 1.0};
    style.color_scrollbar_grab  = .{0.210, 0.290, 0.380, 1.0};
    style.font_size = 16;
    style.padding = 14;
    style.item_spacing = 8;
    style.button_height = 36;
}

render_frame :: (program: *Interactive_Toolbox_Program, time_seconds: float) {
    program.torus.rotation = .{
        0.52 + time_seconds * 0.21,
        time_seconds * 0.39,
        0.12 + time_seconds * 0.10
    };

    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    if cast(Website_Page) program.selected_page == .HOME {
        aspect := cast(float) program.viewport_width / cast(float) program.viewport_height;
        camera_distance := ifx aspect < 0.78 then 8.8 else 7.0;
        Renderer.set_camera(*program.renderer, 0.58, 0.24, camera_distance, aspect);
        Renderer.render(*program.renderer, *program.torus);
    }

    dt := cast(float64) (time_seconds - program.previous_frame_time);
    if program.previous_frame_time == 0 || dt < 0 || dt > 0.25 dt = 0;
    program.previous_frame_time = time_seconds;

    UI.ui_begin_frame(
        program.mouse_x,
        program.mouse_y,
        program.mouse_left_down,
        program.mouse_right_down,
        program.mouse_scroll_y,
        cast(float32) program.viewport_width,
        cast(float32) program.viewport_height,
        dt
    );
    program.mouse_scroll_y = 0;

    draw_site(program);

    UI.ui_end_frame();
    UI_Renderer.render_ui(*program.ui_renderer, *program.ui_context);
}

#scope_file

draw_site :: (program: *Interactive_Toolbox_Program) {
    compact := program.viewport_width < 680;
    navigation_height: float32 = ifx compact then 96.0 else 104.0;

    UI.ui_begin_panel("site_navigation", navigation_height);
    UI.ui_push_style_float(.FONT_SIZE, ifx compact then 18.0 else 21.0);
    UI.ui_label_colored("INTERACTIVE TOOLBOX", UI.ui_ctx.style.color_accent);
    UI.ui_pop_style_float(.FONT_SIZE);
    draw_navigation_tabs(program);
    UI.ui_end_panel();

    if cast(Website_Page) program.selected_page == .JAIDE draw_jaide_page(program);
    browser_sync_selected_page(program.selected_page);
}

draw_navigation_tabs :: (program: *Interactive_Toolbox_Program) {
    style := *UI.ui_ctx.style;
    navigation_items := string.["HOME", "JAIDE"];

    UI.ui_push_id("primary_navigation");
    UI.ui_begin_row();

    for i: 0..navigation_items.count-1 {
        item := navigation_items[i];
        tab_id := UI.ui_get_id(item);
        text_width := UI.msdf_measure_text_pixels(UI.ui_ctx.font, item, style.font_size);
        rect := UI.ui_allocate_rect(text_width + style.padding * 2, style.button_height);

        UI.ui_try_hot(tab_id, rect);
        UI.ui_try_active(tab_id);
        if UI.ui_was_clicked(tab_id) {
            program.selected_page = cast(s32) i;
            UI.ui_emit_audio(.TAB_SELECT, tab_id);
        }

        background: Vector4;
        if program.selected_page == cast(s32) i background = style.color_accent;
        else if UI.ui_is_active(tab_id) background = style.color_bg_active;
        else if UI.ui_is_hot(tab_id) background = style.color_bg_hover;
        else background = style.color_bg;

        UI.ui_cmd_rect(rect, background);
        text_x := UI.ui_text_centered_x(rect, item, style.font_size);
        text_y := UI.ui_text_baseline_y(rect, style.font_size) - 3.0;
        UI.ui_cmd_text(item, text_x, text_y, style.font_size, style.color_text);
    }

    UI.ui_end_row();
    UI.ui_pop_id();
}

draw_jaide_page :: (program: *Interactive_Toolbox_Program) {
    page_height := UI.ui_available_height();
    if page_height < 120 page_height = 120;

    if program.viewport_width < 760 {
        draw_jaide_compact(program, page_height);
        return;
    }

    available_width := UI.ui_available_width();
    sidebar_width: float32 = 252;
    reading_width := max(available_width - sidebar_width - UI.ui_ctx.style.item_spacing, 1.0);

    UI.ui_begin_row();
    UI.ui_begin_column(sidebar_width);
    draw_jaide_sidebar(program, page_height);
    UI.ui_end_column();

    UI.ui_begin_column(reading_width);
    UI.ui_begin_panel("jaide_reading_panel", page_height);
    reading_height := UI.ui_available_height();
    UI.ui_begin_scroll_region_ex(tprint("jaide_content_%", program.jaide_section), reading_height, 10);
    begin_guide_content(900);
    draw_guide_content(program);
    end_guide_content();
    UI.ui_end_scroll_region();
    UI.ui_end_panel();
    UI.ui_end_column();
    UI.ui_end_row();
}

JAIDE_SECTION_NAMES :: string.[
    "OVERVIEW",
    "REQUIREMENTS",
    "QUICK START",
    "INTERFACE",
    "LANGUAGE TOOLS",
    "FIND & NAVIGATE",
    "FILES & PANES",
    "BUILD & RUN",
    "KEYBINDINGS",
    "MENUS",
    "CONFIGURATION",
    "TROUBLESHOOTING"
];

JAIDE_BLUE :: Vector4.{0.560, 0.760, 1.000, 1.0};

draw_jaide_sidebar :: (program: *Interactive_Toolbox_Program, height: float32) {
    UI.ui_begin_panel("jaide_sidebar", height);
    UI.ui_push_style_float(.FONT_SIZE, 23);
    UI.ui_label_colored("JAIDE", JAIDE_BLUE);
    UI.ui_pop_style_float(.FONT_SIZE);
    UI.ui_label_disabled("USER GUIDE");
    UI.ui_separator();

    navigation_height := UI.ui_available_height();
    UI.ui_begin_scroll_region_ex("jaide_sidebar_scroll", navigation_height, 0);
    UI.ui_push_style_float(.FONT_SIZE, 14);
    for i: 0..JAIDE_SECTION_NAMES.count-1 {
        if draw_guide_navigation_button(JAIDE_SECTION_NAMES[i], program.jaide_section == cast(s32) i) {
            program.jaide_section = cast(s32) i;
        }
    }
    UI.ui_pop_style_float(.FONT_SIZE);
    UI.ui_end_scroll_region();
    UI.ui_end_panel();
}

draw_jaide_compact :: (program: *Interactive_Toolbox_Program, height: float32) {
    UI.ui_begin_panel("jaide_compact", height);
    UI.ui_label_colored("JAIDE / USER GUIDE", JAIDE_BLUE);
    compact_button_width := (UI.ui_available_width() - UI.ui_ctx.style.item_spacing) * 0.5;
    UI.ui_begin_row();
    if draw_guide_navigation_button("PREV", false, compact_button_width) {
        program.jaide_section -= 1;
        if program.jaide_section < 0 program.jaide_section = cast(s32) JAIDE_SECTION_NAMES.count - 1;
    }
    if draw_guide_navigation_button("NEXT", false, compact_button_width) {
        program.jaide_section += 1;
        if program.jaide_section >= cast(s32) JAIDE_SECTION_NAMES.count program.jaide_section = 0;
    }
    UI.ui_end_row();
    UI.ui_label_disabled(tprint("% / %  %", program.jaide_section + 1, JAIDE_SECTION_NAMES.count, JAIDE_SECTION_NAMES[program.jaide_section]));
    UI.ui_separator();

    reading_height := UI.ui_available_height();
    UI.ui_begin_scroll_region_ex(tprint("jaide_compact_content_%", program.jaide_section), reading_height, 8);
    draw_guide_content(program);
    UI.ui_end_scroll_region();
    UI.ui_end_panel();
}

draw_guide_navigation_button :: (label: string, selected: bool, width: float32 = 0) -> bool {
    style := *UI.ui_ctx.style;
    button_id := UI.ui_get_id(label);
    rect := UI.ui_allocate_rect(width, style.button_height);

    UI.ui_try_hot(button_id, rect);
    UI.ui_try_active(button_id);
    clicked := UI.ui_was_clicked(button_id);

    background: Vector4;
    if selected background = .{0.110, 0.265, 0.390, 1.0};
    else if UI.ui_is_active(button_id) background = style.color_bg_active;
    else if UI.ui_is_hot(button_id) background = style.color_bg_hover;
    else background = .{0.045, 0.060, 0.090, 1.0};

    UI.ui_cmd_rect(rect, background);
    if selected UI.ui_cmd_rect_outline(rect, JAIDE_BLUE);
    text_y := UI.ui_text_baseline_y(rect, style.font_size) - 3.0;
    UI.ui_cmd_text(label, rect.x + style.padding, text_y, style.font_size, ifx selected then JAIDE_BLUE else style.color_text);
    return clicked;
}

begin_guide_content :: (maximum_width: float32) {
    available := UI.ui_available_width();
    content_width := min(available, maximum_width);
    gutter := max((available - content_width) * 0.5, 0.0);

    UI.ui_begin_row();
    if gutter > 0 {
        UI.ui_begin_column(gutter);
        UI.ui_end_column();
    }
    UI.ui_begin_column(content_width);
}

end_guide_content :: () {
    UI.ui_end_column();
    UI.ui_end_row();
}

draw_guide_content :: (program: *Interactive_Toolbox_Program) {
    if program.jaide_section == {
        case 0; draw_guide_overview();
        case 1; draw_guide_requirements();
        case 2; draw_guide_quick_start();
        case 3; draw_guide_interface();
        case 4; draw_guide_language_tools();
        case 5; draw_guide_find_and_navigate();
        case 6; draw_guide_files_and_panes();
        case 7; draw_guide_build_and_run();
        case 8; draw_guide_keybindings();
        case 9; draw_guide_menus();
        case 10; draw_guide_configuration();
        case 11; draw_guide_troubleshooting();
        case; draw_guide_pending_section(program.jaide_section);
    }
}

guide_heading :: (eyebrow: string, title: string, intro: string) {
    UI.ui_spacing(18);
    UI.ui_label_colored(eyebrow, JAIDE_BLUE);
    UI.ui_push_style_float(.FONT_SIZE, ifx UI.ui_available_width() < 620 then 30.0 else 43.0);
    UI.ui_label_wrapped(title);
    UI.ui_pop_style_float(.FONT_SIZE);
    UI.ui_label_disabled_wrapped(intro);
    UI.ui_spacing(12);
}

guide_card_height :: (title: string, body: string, width: float32) -> float32 {
    style := *UI.ui_ctx.style;
    inner_width := max(width - style.padding * 2, 1.0);
    result := UI.ui_wrapped_text_height(title, inner_width)
            + UI.ui_wrapped_text_height(body, inner_width)
            + style.padding * 2
            + style.item_spacing * 3
            + style.border_width;
    return max(result, 116.0);
}

guide_card :: (id: string, title: string, body: string, height: float32 = 0) {
    required_height := guide_card_height(title, body, UI.ui_available_width());
    if height < required_height height = required_height;
    UI.ui_begin_panel(id, height);
    UI.ui_label_colored_wrapped(title, JAIDE_BLUE);
    UI.ui_separator();
    UI.ui_label_disabled_wrapped(body);
    UI.ui_end_panel();
}

guide_two_cards :: (first_id: string, first_title: string, first_body: string,
                    second_id: string, second_title: string, second_body: string) {
    available := UI.ui_available_width();
    if available < 680 {
        guide_card(first_id, first_title, first_body);
        guide_card(second_id, second_title, second_body);
        return;
    }

    card_width := (available - UI.ui_ctx.style.item_spacing) * 0.5;
    row_height := max(
        guide_card_height(first_title, first_body, card_width),
        guide_card_height(second_title, second_body, card_width)
    );

    UI.ui_begin_row();
    UI.ui_begin_column(card_width);
    guide_card(first_id, first_title, first_body, row_height);
    UI.ui_end_column();
    UI.ui_begin_column(card_width);
    guide_card(second_id, second_title, second_body, row_height);
    UI.ui_end_column();
    UI.ui_end_row();
}

guide_topic :: (title: string, body: string) {
    UI.ui_spacing(12);
    UI.ui_push_style_float(.FONT_SIZE, 19);
    UI.ui_label_wrapped(title);
    UI.ui_pop_style_float(.FONT_SIZE);
    UI.ui_label_disabled_wrapped(body);
}

guide_callout :: (id: string, title: string, body: string) {
    UI.ui_spacing(12);
    guide_card(id, title, body);
}

guide_bullet :: (text: string) {
    UI.ui_label_wrapped(tprint("-  %", text));
}

draw_guide_overview :: () {
    guide_heading(
        "COMPLETE REFERENCE",
        "Everything you need to work in Jaide.",
        "Jaide is a focused code editor for the Jai programming language. It combines a fast, project-oriented editor with Jai-aware parsing, symbol search, navigation, refactoring, and a configurable build workflow."
    );

    UI.ui_separator_text("AT A GLANCE");
    guide_bullet("JAI-SPECIFIC LANGUAGE SUPPORT");
    guide_bullet("PROJECT INDEXING AND SYMBOL SEARCH");
    guide_bullet("SPLIT PANES, DEFINITION LOOKUP, AND USAGES");
    guide_bullet("CONFIGURABLE BUILD AND RUN WORKFLOW");
    UI.ui_spacing(14);

    guide_card(
        "guide_compiler_callout",
        "THE JAI COMPILER IS REQUIRED",
        "Jai is not publicly distributed with Jaide. You need access to the Jai private beta and a local Jai installation. Jaide derives the compiler executable and standard modules from that installation.",
        0
    );
    UI.ui_spacing(30);
}

draw_guide_requirements :: () {
    guide_heading(
        "START HERE",
        "Requirements and compatibility",
        "Jaide's parser and language-aware features track the current Jai language. Use a recent compiler build for the best results."
    );

    guide_card("guide_req_install", "JAI INSTALL DIRECTORY", "Select the root of your Jai installation, not its bin directory. Jaide looks for the platform compiler plus a valid modules/Basic.");
    guide_card("guide_req_tools", "TWO EXECUTABLES", "A packaged installation contains the editor and its programming server. Keep them together; indexing and language navigation depend on the server.");
    guide_card("guide_req_language", "CURRENT LANGUAGE BEHAVIOR", "Parsing and name resolution are designed around current Jai syntax. Older projects may contain removed directives or overloads that now produce diagnostics.");
    guide_card("guide_req_text", "TEXT FILES", "Jaide opens editable text files and gives .jai files its language features. Binary-looking files are rejected instead of being displayed as corrupted text.");
    UI.ui_spacing(30);
}

draw_guide_quick_start :: () {
    guide_heading(
        "FIRST LAUNCH",
        "Quick start",
        "Go from a fresh install to a running Jai program in four steps."
    );

    guide_two_cards(
        "quick_jai", "01 / SELECT YOUR JAI INSTALLATION", "Choose the root of the Jai installation on first launch. Change it later with Tools > Jai Setup.",
        "quick_project", "02 / OPEN OR CREATE A PROJECT", "Open Project selects an existing directory. Create Project prepares build.jai and src/main.jai in an empty directory."
    );
    guide_two_cards(
        "quick_build", "03 / CONFIRM THE BUILD", "Review the detected command, working directory, and analysis entry. Jaide will not run a detected command until you confirm it.",
        "quick_run", "04 / BUILD, THEN RUN", "Press Ctrl + B or click Build. When it succeeds, click Run. Build output locations jump to the reported file and line."
    );

    guide_callout(
        "quick_file_note",
        "A SINGLE FILE DOES NOT REQUIRE A PROJECT",
        "Use File > Open File when you only want to edit text. Project search, build settings, the tree, and full language indexing become available after opening a project."
    );
    UI.ui_spacing(30);
}

draw_guide_interface :: () {
    guide_heading(
        "WORKSPACE MAP",
        "Interface tour",
        "The main window stays compact: controls at the top, project context around the editor, and transient results in focused windows."
    );

    guide_two_cards(
        "interface_tree", "01 / PROJECT TREE", "Browse directories, open files, rename or delete files, and drag files between folders. Drag the divider to resize the panel.",
        "interface_tabs", "02 / WORKSPACE TABS", "Each numbered tab remembers its pane arrangement and active view. Use + for a new workspace and x to close one."
    );
    guide_two_cards(
        "interface_edit", "03 / EDITOR PANES", "Edit, select, scroll, zoom, and navigate. Every pane keeps its own cursor, selection, scroll position, and font size.",
        "interface_outline", "04 / FILE OUTLINE", "See the current Jai file's types, file-level variables, and procedures. Collapse groups or click an entry to jump."
    );
    guide_two_cards(
        "interface_results", "05 / RESULT WINDOWS", "Go to, usages, rename, build output, run output, compiler explanations, and setup appear in movable focused windows.",
        "interface_status", "06 / STATUS BAR", "Shows the active path, dirty marker, line and column, editor messages, local time, and frame rate."
    );

    guide_topic("Show or hide supporting panels", "Use View > Toggle Project Tree and View > Toggle Outline. Both side panels have draggable dividers. View > Enable Line Wrap wraps long lines; disabling it restores horizontal scrolling.");
    UI.ui_spacing(30);
}

draw_guide_language_tools :: () {
    guide_heading(
        "JAI-AWARE EDITING",
        "Jai language tools",
        "A companion programming server provides parsing, indexing, name resolution, document symbols, semantic tokens, references, and rename operations."
    );

    guide_two_cards(
        "language_point", "01 / POINT AT CODE", "Use an identifier, directive, note, import, or loaded-file path.",
        "language_action", "02 / CHOOSE AN ACTION", "Double-click for a definition, Shift-click for usages, or Ctrl-click to rename."
    );
    guide_card("language_result", "03 / NAVIGATE OR INSPECT", "Open source, view resolved occurrences, rename symbols, or read explanations for compiler-provided constructs.");

    guide_topic("Go to definition", "Double-click an identifier to open its declaration in the active pane. The destination is centered and the origin enters jump history. Double-right-click to return.");
    guide_topic("Show usages and rename", "Shift-click opens all resolved occurrences with source previews. Ctrl-click opens the same project-aware list in rename mode. Enter a valid Jai identifier and apply Rename to update the declaration and references.");
    guide_topic("Imports and loaded files", "Double-click the quoted path in #load to open a file relative to the current source. Double-click an #import module string to open it from the configured Jai installation. Local tbx imports resolve inside the project's src tree.");
    guide_topic("Compiler-provided symbols", "When a construct has no source declaration, Jaide can open Builtin Info instead. This covers common types, constants, context forms, and metaprogramming directives such as #run, #expand, and #module_parameters.");
    guide_topic("Declaration notes", "Jai notes use @Name or @Name(arguments). Jaide colors the whole note like a comment. Custom metadata such as @NoProfile gets its behavior from the project's metaprogram, module, or application.");

    guide_callout("language_semantic", "SEMANTIC HIGHLIGHTING", "Lexical color appears immediately. The programming server then refines resolved identifiers into types, procedures, parameters, variables, properties, macros, constants, and declarations.");
    guide_callout("language_typing", "WHILE YOU TYPE", "Jaide shifts unaffected semantic ranges across edits, uses lexical color for the active token, and refreshes semantic highlighting and the outline after a short delay.");
    UI.ui_spacing(30);
}

draw_guide_find_and_navigate :: () {
    guide_heading(
        "SEARCH",
        "Find and navigate",
        "Use in-file search for literal text and the Go to window for fuzzy file and symbol navigation."
    );

    guide_topic("Find in the current file", "Press Ctrl + F, type a text query, then use Enter for the next match or Shift + Enter for the previous match. Search wraps at either end. Press Esc to close it.");
    guide_topic("Go to files and symbols", "Press Ctrl + P or use Navigate > Go to. Fuzzy search mixes files, procedures, types, and variables. Type to refine, use arrow keys or Tab to move, Enter to open, and Esc to cancel.");

    guide_two_cards(
        "find_kind", "FILTER BY KIND", "Choose All, Files, Procedures, Types, or Variables. Procedure results include compact signatures and file locations.",
        "find_scope", "FILTER BY SCOPE", "Choose Current file / Open files, Project, or Jai modules. Project and module catalogs come from the programming server."
    );

    guide_callout(
        "find_shortcuts",
        "DIRECT FILE-FINDER SHORTCUTS",
        "Ctrl + Space searches open files. Shift + Space searches project files. Ctrl + Shift + Space searches the configured Jai modules."
    );
    UI.ui_spacing(30);
}

draw_guide_files_and_panes :: () {
    guide_heading(
        "WORKSPACE",
        "Files, tabs, and panes",
        "Documents and views are separate: one file can appear in several panes while each pane keeps its own viewing state."
    );

    UI.ui_separator_text("PROJECT TREE ACTIONS");
    guide_bullet("CLICK A FILE TO OPEN IT; CLICK A DIRECTORY TO EXPAND OR COLLAPSE.");
    guide_bullet("RIGHT-CLICK A FILE TO RENAME IT OR OPEN DELETE CONFIRMATION.");
    guide_bullet("DRAG A FILE TO A FOLDER OR BACK TO THE PROJECT ROOT.");
    guide_bullet("MOVE AND RENAME NEVER OVERWRITE AN EXISTING DESTINATION.");
    guide_bullet("DIRECTORY SYMLINKS ARE NOT TRAVERSED OR ACCEPTED AS MOVE TARGETS.");

    guide_topic("Workspace tabs and shared documents", "The numbered tabs are workspace tabs, not one-file-only tabs. A tab owns an editor layout with one or more panes. When the same file is visible twice, edits are shared but cursor, selection, scroll, and zoom stay pane-local.");
    guide_topic("Create and resize split panes", "Move near a pane edge until a subtle handle appears. Drag inward and release on the highlighted preview. Drag the divider to resize. Use a pane's x to close one view; the final pane cannot be closed this way.");
    guide_topic("Swap panes", "Hold Ctrl + Alt, drag from one pane, and release over another pane in the same tab. Release over the source, outside the panes, or press Esc to cancel.");
    guide_topic("Persistent undo", "Jaide stores an undo sidecar for each opened file. Cursor, selection, undo, and redo are restored only when the on-disk contents still match.");
    UI.ui_spacing(30);
}

draw_guide_build_and_run :: () {
    guide_heading(
        "PROJECT WORKFLOW",
        "Build and run",
        "Build commands are project-specific and must be confirmed once. Jaide keeps the saved command separate from the project repository."
    );

    UI.ui_separator_text("AUTOMATIC BUILD DETECTION");
    guide_bullet("A CONVENTIONAL TOP-LEVEL build.jai.");
    guide_bullet("OTHER TOP-LEVEL JAI BUILD METAPROGRAMS.");
    guide_bullet("COMMON BUILD SCRIPTS FOR THE CURRENT PLATFORM.");
    guide_bullet("A SINGLE first.jai, main.jai, OR SOLE JAI SOURCE FILE.");
    UI.ui_label_disabled_wrapped("If several candidates are found, choose one from Detected. Jaide never runs a detected command until you confirm it.");

    UI.ui_spacing(16);
    UI.ui_separator_text("THE THREE BUILD FIELDS");
    UI.ui_begin_table("build_field_table", 3);
    UI.ui_table_header_row(string.["FIELD", "EXAMPLE", "CONTROLS"]);
    guide_table_row3("Command", "${jai} build.jai", "Executable and arguments");
    guide_table_row3("Working directory", ".", "Where the build starts");
    guide_table_row3("Analysis entry", "build.jai", "Indexing seed");
    UI.ui_end_table();

    guide_topic("Building", "Click Build or press Ctrl + B. If files are unsaved, choose Save, Save All, or Done to continue with the on-disk state. The Build Result window captures output and makes recognized source locations clickable.");
    guide_topic("Running", "Run launches the expected executable from bin/<project-folder-name>, uses the project root as its working directory, and streams output into the Run Output window. Use Stop to terminate it.");
    guide_callout("run_note", "RUN DOES NOT BUILD AUTOMATICALLY", "If a build emits a differently named or located executable, the current Run button will not find it. Match the project folder name under bin, or launch that target outside Jaide.");
    UI.ui_spacing(30);
}

guide_table_row3 :: (first: string, second: string, third: string) {
    UI.ui_table_next_row();
    UI.ui_table_next_column(first);
    UI.ui_table_next_column(second);
    UI.ui_table_next_column(third);
}

guide_key_row :: (keys: string, action: string) {
    UI.ui_table_next_row();
    UI.ui_table_next_column(keys);
    UI.ui_table_next_column(action);
}

draw_guide_keybindings :: () {
    guide_heading(
        "SHORTCUT REFERENCE",
        "All current keybindings",
        "Jaide uses Ctrl as the primary modifier on every platform."
    );

    UI.ui_separator_text("GLOBAL AND PROJECT");
    UI.ui_begin_table("global_key_table", 2);
    UI.ui_table_header_row(string.["KEYS", "ACTION"]);
    guide_key_row("Ctrl + P", "Open Go to");
    guide_key_row("Ctrl + Space", "Find open file");
    guide_key_row("Shift + Space", "Find project file");
    guide_key_row("Ctrl + Shift + Space", "Find Jai module file");
    guide_key_row("Ctrl + B", "Build project");
    guide_key_row("Ctrl + S", "Save active document");
    guide_key_row("Ctrl + F", "Find in file");
    UI.ui_end_table();

    UI.ui_spacing(16);
    UI.ui_separator_text("TEXT EDITING");
    UI.ui_begin_table("editing_key_table", 2);
    UI.ui_table_header_row(string.["KEYS", "ACTION"]);
    guide_key_row("Ctrl + A / C / X / V", "Select all / copy / cut / paste");
    guide_key_row("Ctrl + Z", "Undo");
    guide_key_row("Ctrl + Shift + Z / Ctrl + Y", "Redo");
    guide_key_row("Enter", "New line with inferred indent");
    guide_key_row("Tab / Shift + Tab", "Indent / unindent");
    guide_key_row("Backspace / Delete", "Delete backward / forward");
    guide_key_row("Left / Right", "Move by character");
    guide_key_row("Up / Down", "Move by displayed row");
    guide_key_row("Home / End", "Move to line boundary");
    UI.ui_end_table();

    UI.ui_spacing(16);
    UI.ui_separator_text("FIND, NAVIGATE, AND POINTER");
    UI.ui_begin_table("navigation_key_table", 2);
    UI.ui_table_header_row(string.["INPUT", "ACTION"]);
    guide_key_row("Enter / Shift + Enter", "Next / previous file match");
    guide_key_row("Tab / Shift + Tab", "Move through Go to results");
    guide_key_row("Esc", "Close or cancel the focused action");
    guide_key_row("Double left-click", "Go to definition");
    guide_key_row("Shift + click", "Show usages");
    guide_key_row("Ctrl + click", "Rename symbol");
    guide_key_row("Double right-click", "Jump back");
    guide_key_row("Mouse wheel", "Vertical scroll");
    guide_key_row("Shift + wheel", "Fast vertical scroll");
    guide_key_row("Alt + wheel", "Horizontal scroll");
    guide_key_row("Ctrl + wheel", "Zoom pane text");
    guide_key_row("Ctrl + Alt + drag", "Swap panes");
    UI.ui_end_table();
    UI.ui_spacing(30);
}

draw_guide_menus :: () {
    guide_heading(
        "COMMAND MAP",
        "Menu reference",
        "Every command currently exposed in the top menu bar. Build and Run stay visible at the far right."
    );

    guide_two_cards(
        "menu_file", "FILE", "Open File, Open Project, Open Recent, Create Project, Save.",
        "menu_edit", "EDIT", "Undo, Redo."
    );
    guide_two_cards(
        "menu_view", "VIEW", "Toggle Project Tree, Toggle Outline, Enable or Disable Line Wrap.",
        "menu_project", "PROJECT", "Configure Build, Re-detect Build Command, Open Project Config."
    );
    guide_two_cards(
        "menu_navigate", "NAVIGATE", "Open Go to for fuzzy file and symbol search.",
        "menu_tools", "TOOLS", "Jai Setup, Open Application Config."
    );
    UI.ui_spacing(30);
}

draw_guide_configuration :: () {
    guide_heading(
        "LOCAL STATE",
        "Configuration and saved state",
        "Jaide keeps machine-specific paths and editor state outside your source code."
    );

    guide_topic("Application configuration", "Use Tools > Open Application Config to edit data/cfg.ini. Saving reloads it immediately.");
    UI.ui_begin_panel("application_config", 220);
    UI.ui_label_colored("data/cfg.ini", JAIDE_BLUE);
    UI.ui_separator();
    UI.ui_label("[jai]");
    UI.ui_label_disabled("jai_path = /path/to/jai");
    UI.ui_label("[editor]");
    UI.ui_label_disabled("scroll_lines = 4");
    UI.ui_label_disabled("fast_scroll_lines = 10");
    UI.ui_label("[recent_projects]");
    UI.ui_label_disabled("project_0 = /path/to/a/project");
    UI.ui_end_panel();

    guide_topic("Project configuration", "Confirmed build settings live in a path-keyed file under data/project_settings. This avoids modifying an external project just to use Jaide.");
    UI.ui_begin_panel("project_config", 260);
    UI.ui_label_colored("PROJECT SETTINGS", JAIDE_BLUE);
    UI.ui_separator();
    UI.ui_label("[project]");
    UI.ui_label_disabled("root = /path/to/project");
    UI.ui_label("[build]");
    UI.ui_label_disabled("confirmed = true");
    UI.ui_label_disabled("command = ${jai} build.jai");
    UI.ui_label_disabled("working_directory = .");
    UI.ui_label_disabled("analysis_entry = build.jai");
    UI.ui_end_panel();

    guide_topic("Recent projects and portable builds", "Up to eight valid recent project directories are retained. Packaged builds anchor their writable data directory beside the Jaide executable, so shortcuts do not depend on the shell's working directory.");
    UI.ui_spacing(30);
}

draw_guide_troubleshooting :: () {
    guide_heading(
        "COMMON FIXES",
        "Troubleshooting",
        "Start with these checks for the most common setup, build, and navigation problems."
    );

    guide_card("trouble_language", "LANGUAGE NAVIGATION OR OUTLINE IS UNAVAILABLE", "Confirm Tools > Jai Setup points to the Jai installation root and that the programming executable is beside Jaide. For a custom layout, verify the Analysis entry.");
    guide_card("trouble_confirm", "BUILD ASKS FOR CONFIRMATION EVERY TIME", "Open Project > Configure Build, make sure Command is not empty, and press Save. If the project moved, reopen it from the new path.");
    guide_card("trouble_run", "BUILD SUCCEEDS, BUT RUN CANNOT FIND THE EXECUTABLE", "Run expects bin/<project-folder-name>. Adjust the build output to match. The Create Project template already follows this convention.");
    guide_card("trouble_old", "AN OLDER JAI PROJECT SHOWS ERRORS", "Jaide targets current compiler syntax. Older code may use removed directives or now-ambiguous overloads. The editor remains usable while the compiler reports the incompatibility.");
    guide_card("trouble_click", "A DOUBLE-CLICK DOES NOT NAVIGATE", "Definition lookup needs a resolvable identifier in a Jai file and a ready programming server. Compiler constructs open help only when Jaide has an explanation for them.");

    guide_callout(
        "trouble_support",
        "REPORT ISSUES AND GET HELP",
        "Use the Jaide Discord group at discord.gg/AQp5V2fH4M. Include your operating system, Jai compiler version, a minimal project or code sample, and exact reproduction steps."
    );
    UI.ui_label_disabled_wrapped("Jaide is developed alongside the evolving Jai language. Additional editor features and deeper language integration are planned as both mature.");
    UI.ui_spacing(30);
}

draw_guide_pending_section :: (section: s32) {
    guide_heading("JAIDE USER GUIDE", JAIDE_SECTION_NAMES[section], "This section is being adapted to the Interactive Toolbox UI.");
}

vertex :: inline (position: WebGL_Vector3, normal: WebGL_Vector3, color: WebGL_Vector3) -> WebGL_Vertex {
    return .{position, normal, color};
}

create_torus_geometry :: (major_radius: float, minor_radius: float, major_segments: s32, minor_segments: s32) -> WebGL_Geometry {
    result: WebGL_Geometry;
    tau :: cast(float) 6.28318530718;

    for major: 0..major_segments-1 {
        major_angle := cast(float) major / cast(float) major_segments * tau;
        major_cos := cos(major_angle);
        major_sin := sin(major_angle);

        for minor: 0..minor_segments-1 {
            minor_angle := cast(float) minor / cast(float) minor_segments * tau;
            minor_cos := cos(minor_angle);
            minor_sin := sin(minor_angle);

            radius := major_radius + minor_radius * minor_cos;
            position := WebGL_Vector3.{radius * major_cos, minor_radius * minor_sin, radius * major_sin};
            normal := WebGL_Vector3.{minor_cos * major_cos, minor_sin, minor_cos * major_sin};
            phase := 0.5 + 0.5 * sin(major_angle * 2.0 + minor_angle);
            color := WebGL_Vector3.{
                0.15 + 0.50 * phase,
                0.84 - 0.42 * phase,
                0.72 + 0.23 * (1.0 - phase)
            };
            array_add(*result.vertices, vertex(position, normal, color));
        }
    }

    for major: 0..major_segments-1 {
        next_major := (major + 1) % major_segments;
        for minor: 0..minor_segments-1 {
            next_minor := (minor + 1) % minor_segments;
            a := cast(u32) (major * minor_segments + minor);
            b := cast(u32) (next_major * minor_segments + minor);
            c := cast(u32) (next_major * minor_segments + next_minor);
            d := cast(u32) (major * minor_segments + next_minor);
            array_add(*result.indices, a, c, b, a, d, c);
        }
    }

    return result;
}

browser_sync_selected_page :: (page: s32) #foreign;

#import "Basic";
