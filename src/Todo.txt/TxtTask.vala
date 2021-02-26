/* Copyright 2016-2020 Go For It! developers
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

using GOFI.TXT.TxtUtils;

enum TxtPartType {
    TAG,
    WORD,
    PROJECT,
    CONTEXT,
    URI;
}

[Compact]
class TxtPart {
    public TxtPartType part_type;
    public string content;
    public string tag_name;

    public TxtPart.word (string word) {
        this.part_type = TxtPartType.WORD;
        this.content = word;
    }

    public TxtPart.tag (string tag_name, string tag_value) {
        this.part_type = TxtPartType.TAG;
        this.tag_name= tag_name;
        this.content = tag_value;
    }

    public TxtPart.context (string context) {
        this.part_type = TxtPartType.CONTEXT;
        this.content = context;
    }

    public TxtPart.project (string project) {
        this.part_type = TxtPartType.PROJECT;
        this.content = project;
    }

    public TxtPart.uri (string? uri_scheme, string uri_content) {
        this.part_type = TxtPartType.URI;
        this.content = uri_content;
        this.tag_name = uri_scheme;
    }
}

/**
 * This class stores all task information.
 */
class GOFI.TXT.TxtTask : TodoTask {

    public bool done {
        public get {
            return _done;
        }
        public set {
            if (_done != value) {
                if (value && creation_date != null) {
                    completion_date = new GLib.DateTime.now_local ();
                } else {
                    completion_date = null;
                }
                _done = value;
                done_changed ();
            }
        }
    }
    private bool _done;

    public DateTime? creation_date {
        public get;
        public set;
    }

    public DateTime? completion_date {
        public get;
        public set;
    }

    public DateTime? due_date {
        public get;
        public set;
    }

    public uint8 priority {
        public get;
        public set;
    }
    public const uint8 NO_PRIO=127;


    private void set_descr_parts (owned TxtPart[] parts) {
        _parts = (owned) parts;
        description = parts_to_description ();
    }
    public unowned TxtPart[] get_descr_parts () {
        return _parts;
    }
    private TxtPart[] _parts;

    public ICal.Recurrence? rrule {
        get;
        set;
    }

    public signal void done_changed ();

    public TxtTask (string line, bool done) {
        base (line);
        creation_date = null;
        completion_date = null;
        _done = done;
        priority = NO_PRIO;
        set_descr_parts (parse_description (line.split (" "), 0));
    }

    public TxtTask.from_simple_txt (string descr, bool done) {
        base ("");
        creation_date = new GLib.DateTime.now_local ();
        completion_date = null;
        update_from_simple_txt (descr);
    }

    public TxtTask.from_todo_txt (string descr, bool done) {
        base ("");
        var parts = descr.split (" ");
        assert (parts[0] != null);
        uint index = 0;

        _done = parse_done (parts, ref index);
        parse_priority (parts, ref index);
        parse_dates (parts, ref index);

        set_descr_parts (parse_description (parts, index));

        if (description == "") {
            warning ("Task does not have a description: \"%s\"", descr);
            return;
        }
    }

    private inline bool parse_done (string[] parts, ref uint index) {
        if (parts[index] == "x") {
            index++;
            return true;
        }
        return false;
    }

    private inline void parse_priority (string[] parts, ref uint index) {
        if (parts[index] != null && is_priority (parts[index])) {
            priority = parts[index][1] - 65;
            index++;
        } else {
            priority = NO_PRIO;
        }
    }

    private inline DateTime? try_parse_date (string[] parts, ref uint index) {
        uint _index = index;
        if (parts[_index] != null && is_date (parts[_index])) {
            index++;
            return string_to_date (parts[_index]);
        }
        return null;
    }

    private inline void parse_dates (string[] parts, ref uint index) {
        DateTime? date1 = try_parse_date (parts, ref index);
        DateTime? date2 = null;

        if (date1 != null && _done && (date2 = try_parse_date (parts, ref index)) != null) {
            creation_date = date2;
            completion_date = date1;
        } else {
            creation_date = date1;
            completion_date = null;
        }
    }

    private TxtPart tokenize_descr_part (string p) {
        if (is_project_tag (p)) {
            return new TxtPart.project (p.offset (1));
        } else if (is_context_tag (p)) {
            return new TxtPart.context (p.offset (1));
        } else {
            var colon_pos = p.index_of_char (':');
            if (colon_pos > 0 && p.get_char (colon_pos + 1).isgraph ()) {
                var tag_key = p.slice (0, colon_pos);
                var tag_value = p.offset (colon_pos + 1);
                if (is_common_uri_tag (tag_key)) {
                    return new TxtPart.uri (tag_key, tag_value);
                }
                if (tag_value.data[0] == '/' &&
                    tag_value.data[1] == '/' &&
                    tag_value.data[2] != 0
                ) {
                    return new TxtPart.uri (tag_key, tag_value);
                }
                if (tag_value.index_of_char (':') == -1) {
                    return new TxtPart.tag (tag_key, tag_value);
                }
            }
        }
        return new TxtPart.word (p);
    }

    private TxtPart[] parse_description (string[] unparsed, uint offset) {
        string? p;
        TxtPart[] parsed_parts = {};

        for (p=unparsed[offset]; p != null; offset++, p=unparsed[offset]) {
            var t = tokenize_descr_part (p);
            if (t.part_type == TxtPartType.TAG) {
                switch (t.tag_name) {
                    case "timer":
                        if (is_timer_value (t.content)) {
                            timer_value = string_to_timer (t.content);
                            continue;
                        }
                        break;
                    case "duration":
                        uint new_duration = 0;
                        if (match_duration_value (t.content, out new_duration)) {
                            duration = new_duration;
                            continue;
                        }
                        break;
                    case "due":
                        if (is_date (t.content)) {
                            due_date = string_to_date (t.content);
                            continue;
                        }
                        break;
                    case "rrule":
                        rrule = new ICal.Recurrence.from_string (t.content);
                        if (rrule != null) {
                            continue;
                        }
                        break;
                }
            }
            parsed_parts += (owned) t;
        }

        return parsed_parts;
    }

    public void update_from_simple_txt (string descr) {
        var parts = descr.split (" ");
        if (parts[0] == null) {
            description = "";
            priority = NO_PRIO;
            return;
        }
        uint index = 0;

        parse_priority (parts, ref index);

        duration = 0;
        set_descr_parts (parse_description (parts, index));
    }

    public string parts_to_description () {
        var descr_builder = new StringBuilder.sized (100);
        bool add_leading_space = false;
        foreach (unowned TxtPart p in _parts) {
            if (add_leading_space) {
                descr_builder.append_c (' ');
            }
            add_leading_space = true;

            // Adding tag prefix
            switch (p.part_type) {
                case TxtPartType.TAG:
                    descr_builder.append (p.tag_name);
                    descr_builder.append_c (':');
                    break;
                case TxtPartType.PROJECT:
                    descr_builder.append_c ('+');
                    break;
                case TxtPartType.CONTEXT:
                    descr_builder.append_c ('@');
                    break;
                case TxtPartType.URI:
                    if (p.tag_name != null && p.tag_name != "") {
                        descr_builder.append (p.tag_name);
                        descr_builder.append_c (':');
                    }
                    break;
                default:
                    break;
            }

            descr_builder.append (p.content);
        }
        return descr_builder.str;
    }

    private string duration_to_string () {
        uint hours, minutes;
        Utils.uint_to_time (duration, out hours, out minutes, null);
        if (hours > 0) {
            if (minutes > 0) {
                return "duration:%uh-%um".printf (hours, minutes);
            }
            return "duration:%uh".printf (hours);
        } else {
            return "duration:%um".printf (minutes);
        }
    }

    public string to_simple_txt () {
        string prio_str = (priority != NO_PRIO) ? @"($((char) (priority + 65))) " : "";
        string duration_str = duration != 0 ? " " + duration_to_string () : "";

        return prio_str + description + duration_str;
    }

    private string prio_to_string () {
        if (priority >= NO_PRIO) {
            return "";
        } else {
            char prio_char = priority + 65;
            return @"($prio_char) ";
        }
    }

    public string to_txt (bool log_timer) {
        var str_builder = new StringBuilder.sized (100);
        if (done) {
            str_builder.append ("x ");
        }

        str_builder.append (prio_to_string ());

        if (creation_date != null) {
            str_builder.append (date_to_string (creation_date));
            str_builder.append_c (' ');

            if (completion_date != null) {
                str_builder.append (date_to_string (completion_date));
                str_builder.append_c (' ');
            }
        }

        str_builder.append (description);

        if (due_date != null) {
            str_builder.append (" due:");
            str_builder.append (date_to_string (due_date));
        }

        if (rrule != null) {
            str_builder.append (" rrule:");
            str_builder.append (rrule.to_string ());
        }

        if (log_timer && timer_value != 0) {
            str_builder.append (" timer:");
            str_builder.append (timer_to_string (timer_value));
        }

        if (duration != 0) {
            str_builder.append_c (' ');
            str_builder.append (duration_to_string ());
        }

        return str_builder.str;
    }

    public int cmp (TxtTask other) {
        if (other == this) {
            return 0;
        }
        if (this.priority == other.priority) {
            var cmp_tmp = this.description.ascii_casecmp (other.description);
            if (cmp_tmp != 0) {
                return cmp_tmp;
            }
            cmp_tmp = GLib.strcmp (this.description, other.description);
            if (cmp_tmp != 0) {
                return cmp_tmp;
            }
            if (((void*) this) > ((void*) other)) {
                return 1;
            }

            return -1;
        }
        if (this.priority == NO_PRIO) {
            return 1;
        }
        if (other.priority == NO_PRIO) {
            return -1;
        }
        if (this.priority > other.priority) {
            return 1;
        }
        return -1;
    }
}
