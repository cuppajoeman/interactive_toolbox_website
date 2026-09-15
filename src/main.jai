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

    UI.ui_begin_panel("jaide_page", page_height);

    available_width := UI.ui_available_width();
    content_width := min(available_width, 820.0);
    gutter := max((available_width - content_width) * 0.5, 0.0);

    UI.ui_begin_row();
    if gutter > 0 {
        UI.ui_begin_column(gutter);
        UI.ui_end_column();
    }
    UI.ui_begin_column(content_width);

    UI.ui_spacing(ifx program.viewport_height < 620 then 34.0 else 86.0);
    UI.ui_label_colored("INTERACTIVE TOOLBOX", UI.ui_ctx.style.color_accent);
    UI.ui_push_style_float(.FONT_SIZE, ifx program.viewport_width < 680 then 42.0 else 68.0);
    UI.ui_label("JAIDE");
    UI.ui_pop_style_float(.FONT_SIZE);
    UI.ui_separator();
    UI.ui_label_disabled("CONTENT COMING SOON.");

    UI.ui_end_column();
    UI.ui_end_row();
    UI.ui_end_panel();
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
