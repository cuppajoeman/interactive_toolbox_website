// Build the Interactive Toolbox site as a WebAssembly module.

GITHUB_PAGES_DOMAIN :: "interactive-toolbox.com";

#run {
    set_build_options_dc(.{do_output = false});

    make_directory_if_it_does_not_exist(".build", recursive = true);
    make_directory_if_it_does_not_exist("dist/jaide", recursive = true);
    copy_site_files();
    build_web_asset_package();

    workspace := compiler_create_workspace("Interactive Toolbox Website (WASM)");
    options := get_build_options(workspace);
    copy_commonly_propagated_fields(get_build_options(), *options);

    options.output_type                         = .EXECUTABLE;
    options.backend                             = .LLVM;
    options.os_target                           = .WASM;
    options.cpu_target                          = .CUSTOM;
    options.emit_debug_info                     = .DWARF;
    options.backtrace_on_crash                  = .OFF;
    options.output_path                         = "dist/";
    options.output_executable_name              = "main";
    options.llvm_options.target_system_features = "+bulk-memory";
    options.llvm_options.enable_split_modules   = false;
    options.llvm_options.function_sections      = true;

    import_paths: [..] string;
    array_add(*import_paths, tprint("%src", #filepath));
    for options.import_path array_add(*import_paths, it);
    options.import_path = import_paths;

    STACK_SIZE :: 64 * 1024;
    options.additional_linker_arguments = .[
        "--stack-first",
        "-z",
        tprint("stack-size=%", STACK_SIZE),
    ];

    set_build_options(options, workspace);

    remap_import(workspace, "*", "Default_Allocator", "tbx/web/Wasm_Arena");
    remap_import(workspace, "*", "GL", "tbx/web/WebGL_GL");
    remap_import(workspace, "*", "Simple_Package", "tbx/web/Web_Simple_Package");
    remap_import(workspace, "*", "tbx/distance_field_generation", "tbx/web/Web_MSDF_Types");

    add_build_file("src/main.jai", workspace);
}

copy_site_files :: () {
    copy_site_file("src/runtime.js", "dist/runtime.js");
    copy_site_file("site/index.html", "dist/index.html");
    copy_site_file("site/index.html", "dist/jaide/index.html");
    copy_site_file("site/favicon.svg", "dist/favicon.svg");
    copy_site_file("assets/fonts/pt_mono/atlas.png", "dist/atlas.png");
    write_site_file("dist/.nojekyll", "");
    write_site_file("dist/CNAME", tprint("%\n", GITHUB_PAGES_DOMAIN));
}

copy_site_file :: (source_path: string, destination_path: string) {
    contents, ok := read_entire_file(source_path);
    if !ok {
        compiler_report(tprint("Could not read site asset: %", source_path), mode = .ERROR);
        return;
    }
    defer free(contents.data);

    if !write_entire_file(destination_path, contents) {
        compiler_report(tprint("Could not write site asset: %", destination_path), mode = .ERROR);
    }
}

write_site_file :: (destination_path: string, contents: string) {
    if !write_entire_file(destination_path, contents) {
        compiler_report(tprint("Could not write site file: %", destination_path), mode = .ERROR);
    }
}

build_web_asset_package :: () {
    font_metrics_path :: "assets/fonts/pt_mono/atlas.json";
    font_metrics, font_metrics_ok := read_entire_file(font_metrics_path);
    if !font_metrics_ok {
        compiler_report(tprint("Could not read web font metrics: %", font_metrics_path), mode = .ERROR);
        return;
    }
    defer free(font_metrics.data);

    package: Simple_Package.Create_Package;
    Simple_Package.init(*package);
    defer Simple_Package.deinit(*package);

    Simple_Package.add(*package, "fonts/pt_mono/atlas.json", xx font_metrics);
    if !Simple_Package.write(*package, "dist/assets.package") {
        compiler_report("Could not write dist/assets.package", mode = .ERROR);
    }
}

#import "Basic";
#import "Compiler";
#import "File";
Simple_Package :: #import "Simple_Package";
