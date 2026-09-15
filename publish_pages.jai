// Publish the committed dist/ directory to GitHub Pages.
//
// Build and commit the site first, then run:
//     jai-linux publish_pages.jai

#run {
    set_build_options_dc(.{do_output = false});
    publish_pages();
}

publish_pages :: () {
    repository_root := #filepath;

    status_result, status_output, status_error := Process.run_command(
        "git", "status", "--porcelain", "--untracked-files=all",
        working_directory = repository_root,
        capture_and_return_output = true,
    );

    if !command_succeeded(status_result) {
        report_command_failure("Could not inspect the Git working tree", status_result, status_error);
        return;
    }

    if status_output.count != 0 {
        print("The working tree is not clean:\n%\n", status_output);
        compiler_report(
            "Build and commit the site changes before publishing. The gh-pages branch can only contain committed dist/ files.",
            mode = .ERROR,
        );
        return;
    }

    tracked_result, _, tracked_error := Process.run_command(
        "git", "ls-files", "--error-unmatch",
        "dist/index.html", "dist/.nojekyll", "dist/CNAME",
        working_directory = repository_root,
        capture_and_return_output = true,
    );

    if !command_succeeded(tracked_result) {
        report_command_failure(
            "dist/index.html, dist/.nojekyll, and dist/CNAME must be committed before publishing",
            tracked_result,
            tracked_error,
        );
        return;
    }

    print("Publishing the committed dist/ directory to origin/gh-pages...\n");
    publish_result := Process.run_command(
        "git", "subtree", "push", "--prefix", "dist", "origin", "gh-pages",
        working_directory = repository_root,
    );

    if !command_succeeded(publish_result) {
        report_command_failure("GitHub Pages publishing failed", publish_result, "");
        return;
    }

    print("Published successfully.\n");
}

command_succeeded :: (result: Process.Process_Result) -> bool {
    return result.type == .EXITED && result.exit_code == 0;
}

report_command_failure :: (message: string, result: Process.Process_Result, error_output: string) {
    if error_output.count != 0 print("%\n", error_output);
    compiler_report(tprint("% (exit code %).", message, result.exit_code), mode = .ERROR);
}

#import "Basic";
#import "Compiler";
Process :: #import "Process";
