/* Copyright 2020 GoForIt! developers
*
* This file is part of GoForIt!.
*
* GoForIt! is free software: you can redistribute it
* and/or modify it under the terms of version 3 of the
* GNU General Public License as published by the Free Software Foundation.
*
* GoForIt! is distributed in the hope that it will be
* useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
* Public License for more details.
*
* You should have received a copy of the GNU General Public License along
* with GoForIt!. If not, see http://www.gnu.org/licenses/.
*/
namespace GOFI {
    class FileConflict {
        public string? info;
        public string src_uri;
        public string dst_uri;

        public FileConflict (string? info, string src_uri, string dst_uri) {
            this.info = info;
            this.src_uri = src_uri;
            this.dst_uri = dst_uri;
        }
    }

    class ConflictChoices {
        FileConflict[] conflicts;
        FileConflict[] replace_choices;
        FileConflict[] swap_choices;
        FileConflict[] merge_choices;
        // Files that hold both open and done tasks: one kind is moved out
        FileConflict[] move_done_choices;
        FileConflict[] move_open_choices;
        int i;

        public ConflictChoices () {
            i = 0;
            conflicts = {};
            replace_choices = {};
            swap_choices = {};
            merge_choices = {};
            move_done_choices = {};
            move_open_choices = {};
        }

        public void add_conflict (FileConflict conflict) {
            conflicts += conflict;
        }

        public void add_simple_replace (FileConflict simple_replace) {
            replace_choices += simple_replace;
        }

        public void add_simple_swap (FileConflict simple_swap) {
            swap_choices += simple_swap;
        }

        public void add_simple_merge (FileConflict simple_merge) {
            merge_choices += simple_merge;
        }

        /**
         * Moves the done tasks from src to the end of dst; open tasks stay.
         */
        public void add_move_done (FileConflict move_done) {
            move_done_choices += move_done;
        }

        /**
         * Moves the open tasks from src to the end of dst; done tasks stay.
         */
        public void add_move_open (FileConflict move_open) {
            move_open_choices += move_open;
        }

        public unowned FileConflict? get_next_conflict () {
            if (i >= conflicts.length) {
                return null;
            }
            return conflicts[i];
        }

        public void keep () {
            i++;
        }

        public void replace () {
            replace_choices += conflicts[i];
            i++;
        }

        public void swap () {
            swap_choices += conflicts[i];
        }

        public unowned FileConflict[] get_replace_choices () {
            return replace_choices;
        }

        public unowned FileConflict[] get_swap_choices () {
            return swap_choices;
        }

        public unowned FileConflict[] get_merge_choices () {
            return merge_choices;
        }

        public unowned FileConflict[] get_move_done_choices () {
            return move_done_choices;
        }

        public unowned FileConflict[] get_move_open_choices () {
            return move_open_choices;
        }
    }

    class FileConflictDialogWrapper {

        string replace_dialog_primary = _("Replace \"%s\"?");
        string replace_dialog_question = _("Should this file be replaced or should this old file be used?");

        Gtk.MessageDialog dialog;
        ConflictChoices choices;

        public signal void choices_made (ConflictChoices choices);
        public signal void aborted ();

        public FileConflictDialogWrapper () {

        }

        public void show_conflict_dialog (Gtk.Window? window, ConflictChoices choices) {
            this.choices = choices;
            dialog = new Gtk.MessageDialog (
                window,
                Gtk.DialogFlags.MODAL,
                Gtk.MessageType.QUESTION,
                Gtk.ButtonsType.NONE,
                "uninitialized"
            );
            string keep_str = _("Keep old");
            string replace_str = _("Replace");
            dialog.add_button (keep_str, Gtk.ResponseType.REJECT);
            var overwrite_but = dialog.add_button (
                replace_str, Gtk.ResponseType.ACCEPT
            );
            overwrite_but.get_style_context ().add_class ("destructive-action");
            dialog.add_button (_("Cancel"), Gtk.ResponseType.CANCEL);

            update_dialog ();
            dialog.response.connect (handle_confirm_dialog_response);
            dialog.close.connect (on_dialog_closed);
            dialog.show ();
        }

        private void update_dialog () {
            var conflict = choices.get_next_conflict ();
            if (conflict == null) {
                dialog.destroy ();
                dialog = null;
                choices_made (choices);
                return;
            }

            dialog.text = replace_dialog_primary.printf (conflict.dst_uri);
            dialog.secondary_text = conflict.info + "\n" + replace_dialog_question;
        }

        private void handle_confirm_dialog_response (int response_id) {
            switch (response_id) {
                case Gtk.ResponseType.ACCEPT:
                    choices.replace ();
                    update_dialog ();
                    break;
                case Gtk.ResponseType.REJECT:
                    choices.keep ();
                    update_dialog ();
                    break;
                default:
                    dialog.destroy ();
                    dialog = null;
                    aborted ();
                    break;
            }
        }

        private void on_dialog_closed () {
            dialog = null;
            aborted ();
        }
    }
}
