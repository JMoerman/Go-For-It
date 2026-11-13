/* Copyright 2026 GoForIt! developers
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

/**
 * Suggests the +projects and @contexts used in a TaskStore while the user
 * types a new task.
 *
 * Only the last word of the entry is completed, and only when it starts with
 * '+' or '@'. Matching is case-insensitive. The common part of all matching
 * tags is filled in inline (selected, so typing on replaces it); Tab or
 * Right accepts it.
 */
class GOFI.TXT.TagCompletion : Object {
    private unowned Gtk.Entry entry;
    private unowned TaskStore model;
    private Gtk.EntryCompletion completion;
    private Gtk.ListStore tags;
    private bool tags_outdated = true;
    private bool inserting_inline = false;
    private int last_length = 0;
    // Shared prefix shown inline, in the spelling of the stored tags.
    private string? inline_prefix = null;
    // Entry text as typed, without the inline suggestion; null if there is
    // no suggestion shown.
    private string? typed_text = null;

    public TagCompletion (Gtk.Entry entry, TaskStore model) {
        this.entry = entry;
        this.model = model;

        tags = new Gtk.ListStore (1, typeof (string));

        completion = new Gtk.EntryCompletion ();
        completion.model = tags;
        completion.text_column = 0;
        completion.minimum_key_length = 1;
        completion.popup_single_match = true;
        // GTK's own inline completion compares against the whole entry text,
        // so it never fires for a tag at the end of a sentence; see
        // on_entry_changed for the word based replacement.
        completion.inline_completion = false;
        completion.set_match_func (match_func);
        completion.match_selected.connect (on_match_selected);

        entry.completion = completion;
        entry.changed.connect_after (on_entry_changed);
        entry.key_press_event.connect (on_key_press);

        model.task_data_changed.connect (() => {
            tags_outdated = true;
        });
    }

    /**
     * Returns the word that is currently being typed: the part of the entry
     * text after the last space.
     */
    private static string last_word (string text) {
        int space = text.last_index_of_char (' ');
        return text.substring (space + 1);
    }

    private static bool is_tag_word (string word) {
        return word.length >= 1 && (word[0] == '+' || word[0] == '@');
    }

    private static bool tag_matches (string tag, string word) {
        return tag[0] == word[0] &&
               tag.length > word.length &&
               tag.casefold ().has_prefix (word.casefold ());
    }

    private void update_tags () {
        if (!tags_outdated) {
            return;
        }
        tags_outdated = false;

        var seen = new GenericSet<string> (str_hash, str_equal);
        var sorted = new GenericArray<string> ();
        uint n_tasks = model.get_n_items ();
        for (uint i = 0; i < n_tasks; i++) {
            var task = model.get_task (i);
            foreach (unowned TxtPart part in task.get_descr_parts ()) {
                string tag;
                if (part.part_type == TxtPartType.PROJECT) {
                    tag = "+" + part.content;
                } else if (part.part_type == TxtPartType.CONTEXT) {
                    tag = "@" + part.content;
                } else {
                    continue;
                }
                if (!seen.contains (tag)) {
                    seen.add (tag);
                    sorted.add (tag);
                }
            }
        }
        sorted.sort ((a, b) => a.collate (b));

        tags.clear ();
        Gtk.TreeIter iter;
        foreach (unowned string tag in sorted.data) {
            tags.append (out iter);
            tags.set (iter, 0, tag);
        }
    }

    private bool match_func (Gtk.EntryCompletion completion, string key,
                             Gtk.TreeIter iter) {
        // Filter on what the user typed, not on the inline suggestion,
        // otherwise a filled-in tag no longer matches and the list closes.
        string word = last_word (typed_text ?? entry.text);
        if (!is_tag_word (word)) {
            return false;
        }
        string? tag;
        tags.get (iter, 0, out tag);
        return tag != null && tag_matches (tag, word);
    }

    /**
     * Replaces the word being typed with the selected tag.
     */
    private bool on_match_selected (Gtk.EntryCompletion completion,
                                    Gtk.TreeModel model, Gtk.TreeIter iter) {
        string tag;
        model.get (iter, 0, out tag);
        replace_last_word (tag + " ");
        return true;
    }

    private void replace_last_word (string replacement) {
        string text = entry.text;
        int space = text.last_index_of_char (' ');
        inserting_inline = true;
        entry.text = text.substring (0, space + 1) + replacement;
        inserting_inline = false;
        typed_text = null;
        inline_prefix = null;
        last_length = entry.text.length;
        entry.set_position (-1);
    }

    /**
     * Fills in the part that all matching tags have in common, selected,
     * after the cursor. Only done while typing at the end of the text, never
     * after deleting, so Backspace removes the suggestion instead of having
     * it come back.
     */
    private void on_entry_changed () {
        if (inserting_inline) {
            return;
        }
        inline_prefix = null;
        typed_text = null;
        string text = entry.text;
        bool grew = text.length > last_length;
        last_length = text.length;

        string word = last_word (text);
        if (!is_tag_word (word)) {
            return;
        }
        update_tags ();
        if (!grew) {
            return;
        }

        string? prefix = null;
        tags.foreach ((model, path, iter) => {
            string tag;
            model.get (iter, 0, out tag);
            if (tag_matches (tag, word)) {
                prefix = (prefix == null) ? tag : common_prefix (prefix, tag);
            }
            return false;
        });
        if (prefix == null || prefix.length <= word.length) {
            return;
        }

        // Keep what the user typed, add the rest of the shared prefix.
        string addition = prefix.substring (word.length);
        // Let GTK finish handling the key press first, otherwise it moves the
        // cursor after our selection is set.
        Idle.add (() => {
            if (entry.text != text) {
                return Source.REMOVE;
            }
            inserting_inline = true;
            int pos = entry.text.char_count ();
            entry.insert_text (addition, -1, ref pos);
            inserting_inline = false;
            entry.select_region (text.char_count (), -1);
            inline_prefix = prefix;
            typed_text = text;
            return Source.REMOVE;
        });
    }

    private static string common_prefix (string a, string b) {
        string fa = a.casefold ();
        string fb = b.casefold ();
        int n = int.min (fa.char_count (), fb.char_count ());
        int i = 0;
        while (i < n && fa.get_char (fa.index_of_nth_char (i)) ==
                        fb.get_char (fb.index_of_nth_char (i))) {
            i++;
        }
        return a.substring (0, a.index_of_nth_char (i));
    }

    /**
     * Tab or Right accepts an inline suggestion.
     */
    private bool on_key_press (Gdk.EventKey event) {
        if (event.keyval != Gdk.Key.Tab && event.keyval != Gdk.Key.Right) {
            return false;
        }
        int start, end;
        if (!entry.get_selection_bounds (out start, out end) ||
            end != entry.text.char_count ()) {
            return false;
        }
        if (inline_prefix != null) {
            // Also fixes the case: "+pro" becomes "+Prowler", not "+prowler".
            replace_last_word (inline_prefix);
            inline_prefix = null;
        } else {
            entry.select_region (end, end);
            entry.set_position (-1);
        }
        return true;
    }
}
