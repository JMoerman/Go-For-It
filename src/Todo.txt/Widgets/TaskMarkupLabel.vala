/* Copyright 2017-2021 Go For It! developers
*
* This file is part of Go For It!.
*
* Go For It! is free software: you can redistribute it
* and/or modify it under the terms of version 3 of the
* GNU General Public License as published by the Free Software Foundation.
*
* Go For It! is distributed in the hope that it will be
* useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
* Public License for more details.
*
* You should have received a copy of the GNU General Public License along
* with Go For It!. If not, see http://www.gnu.org/licenses/.
*/

class GOFI.TXT.TaskMarkupLabel : Gtk.Label {
    private TxtTask task;

    private string markup_string;

    private const string FILTER_PREFIX = "gofi:";

    public TaskMarkupLabel (TxtTask task) {
        this.task = task;

        update ();

        hexpand = true;
        wrap = true;
        wrap_mode = Pango.WrapMode.WORD_CHAR;
        this.xalign = 0f;

        connect_signals ();
        show_all ();
    }

    private void gen_markup () {
        markup_string = make_links (task.get_descr_parts ());

        var done = task.done;
        var duration = task.duration;

        if (task.priority != TxtTask.NO_PRIO) {
            var prefix = _("priority");
            var priority = task.priority;
            char prio_char = priority + 65;
            markup_string = @"<b><a href=\"$prefix:$prio_char\">($prio_char)</a></b> $markup_string";
        }
        if (duration > 0) {
            var timer_value = task.timer_seconds;
            string timer_str = _("%1$s / %2$s").printf (
                Utils.seconds_to_separated_timer_string (timer_value),
                Utils.seconds_to_separated_timer_string (duration)
            );
            markup_string = "%s <i>(%s)</i>".printf (
                markup_string, timer_str
            );
        }
        if (done) {
            markup_string = "<s>" + markup_string + "</s>";
        }
    }

    /**
     * Used to find projects and contexts and replace those parts with a
     * link.
     * @param description the string to took for contexts or projects
     */
    private string make_links (TxtPart[] description) {
        var length = description.length;
        var markup_parts = new string[length];
        string? delimiter = null, prefix = null, val = null;

        for (uint i = 0; i < length; i++) {
            unowned TxtPart part = description[i];
            val = GLib.Markup.escape_text (part.content);

            switch (part.part_type) {
                case TxtPartType.CONTEXT:
                    prefix = _("context");
                    delimiter = "@";
                    break;
                case TxtPartType.PROJECT:
                    prefix = _("project");
                    delimiter = "+";
                    break;
                case TxtPartType.URI:
                    string uri, display_uri;
                    if (part.tag_name == null || part.tag_name == "") {
                        uri = part.content;
                        display_uri = val;
                    } else {
                        uri = part.tag_name + ":" + part.content;
                        display_uri = part.tag_name + ":" + val;
                    }
                    markup_parts[i] =
                        @"<a href=\"$uri\" title=\"$display_uri\">$display_uri</a>";
                    continue;
                case TxtPartType.TAG:
                    markup_parts[i] = part.tag_name + ":" + val;
                    continue;
                default:
                    markup_parts[i] = val;
                    continue;
            }
            markup_parts[i] = @" <a href=\"$FILTER_PREFIX$prefix:$val\" title=\"$val\">" +
                              @"$delimiter$val</a>";
        }

        return string.joinv (" ", markup_parts);
    }

    private void update () {
        gen_markup ();
        set_markup (markup_string);
    }

    private void connect_signals () {
        task.notify.connect (on_task_notify);
    }

    private void on_task_notify (ParamSpec pspec) {
        switch (pspec.get_name ()) {
            case "description":
            case "priority":
            case "timer-value":
            case "duration":
                update ();
                break;
            default:
                break;
        }
    }
}
