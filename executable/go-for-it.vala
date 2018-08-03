private static string? todo_txt_location = null;
private static bool print_version = false;
private static bool show_about_dialog = false;

/**
 * The entry point for running the application.
 */
public static int main (string[] args) {
    Intl.setlocale(LocaleCategory.MESSAGES, "");
    Intl.textdomain(GOFI.GETTEXT_PACKAGE);
    Intl.bind_textdomain_codeset(GOFI.GETTEXT_PACKAGE, "utf-8");
    string locale_dir = Path.build_filename (GOFI.INSTALL_PREFIX, "share", "locale");
    Intl.bindtextdomain(GOFI.GETTEXT_PACKAGE, locale_dir);

    apply_desktop_specific_tweaks ();

    var context = new OptionContext (GOFI.APP_NAME);
    context.add_main_entries (entries, GOFI.EXEC_NAME);
    context.add_group (Gtk.get_option_group (true));

    try {
        context.parse (ref args);
    } catch (Error e) {
        stdout.printf ("%s: Error: %s \n", GOFI.APP_NAME, e.message);
        return 0;
    }

    if (print_version) {
        stdout.printf ("%s %s\n", GOFI.APP_NAME, GOFI.APP_VERSION);
        stdout.printf ("Copyright 2014-2017 'Go For it!' Developers.\n");
        return 0;
    }

    Main app = new Main (GOFI.APP_ID, todo_txt_location, ApplicationFlags.HANDLES_COMMAND_LINE);
    if (show_about_dialog) {
        app.show_about ();
        return 0;
    }

    int status = app.run (args);
    return status;
}

/**
 * This function handles different tweaks that have to be applied to
 * make Go For It! work properly on certain desktop environments.
 */
public static void apply_desktop_specific_tweaks () {
    string desktop = Environment.get_variable ("DESKTOP_SESSION");

    if (desktop == "ubuntu") {
        // Disable overlay scrollbars on unity, to avoid a strange Gtk bug
        Environment.set_variable ("LIBOVERLAY_SCROLLBAR", "0", true);
    }
}

const OptionEntry[] entries = {
    { "todotxt-dir", 'd', 0, OptionArg.FILENAME, out todo_txt_location, N_("Use different Todo.txt directory"), N_("path") },
    { "version", 'v', 0, OptionArg.NONE, out print_version, N_("Print version info and exit"), null },
    { "about", 'a', 0, OptionArg.NONE, out show_about_dialog, N_("Show about dialog"), null },
    { null }
};

