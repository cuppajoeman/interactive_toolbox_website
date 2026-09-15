OUTPUT_EXECUTABLE_NAME :: "change_me";

Build_Mode :: enum {
    UNOPTIMIZED;
    OPTIMIZED;
}

#run {
    set_build_options_dc(.{do_output = false});

    args := get_build_options().compile_time_command_line;
    build_mode := get_requested_build_optimization_mode(args);

    make_directory_if_it_does_not_exist("bin", recursive = true);

    w := compiler_create_workspace("Target Program");
    options := get_build_options(w);
    copy_commonly_propagated_fields(get_build_options(), *options);
    options.output_executable_name = OUTPUT_EXECUTABLE_NAME;
    apply_build_optimization_options(*options, build_mode);
    options.output_path = "bin/";

    import_path: [..] string;
    array_add(*import_path, ..options.import_path);
    array_add(*import_path, "src/");
    options.import_path = import_path;
    
    set_build_options(options, w);

    add_build_file("src/main.jai", w);
};

get_requested_build_optimization_mode :: (args: [] string) -> Build_Mode {
    if command_line_has_flag("-unoptimized") || command_line_has_flag("-debug") return .UNOPTIMIZED;
    if command_line_has_flag("-optimized") || command_line_has_flag("-o") return .OPTIMIZED;

    return .UNOPTIMIZED;
}

command_line_has_flag :: (flag: string) -> bool {
    return array_find(get_toplevel_command_line(), flag);
}

apply_build_optimization_options :: (options: *Build_Options, mode: Build_Mode) {
    if mode != .OPTIMIZED return;

    set_optimization(options, .VERY_OPTIMIZED, preserve_debug_info = false);
    options.stack_trace = false;
    options.enable_frame_pointers = false;
    options.backtrace_on_crash = .OFF;
    options.array_bounds_check = .OFF;
    options.cast_bounds_check = .OFF;
    options.null_pointer_check = .OFF;
}

#import "Basic";
#import "Compiler";
#import "File";
