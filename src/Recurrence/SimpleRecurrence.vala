/* Copyright 2021 Go For It! developers
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

/**
 * Alternative for ICal.Recurrence which is unsuitable for tasks that repeat
 * based on completion date. For example a task that should be rescheduled in a
 * month from the 31st of January would be scheduled on the 30th of March.
 * (RRULE:FREQ=MONTHLY)
 *
 * It supports a small subset of what ICal.Recurrence supports.
 */
class GOFI.SimpleRecurrence : Object {
    public ICal.RecurrenceFrequency freq {
        get;
        set;
    }

    public short interval {
        get;
        set;
    }

    public short month_day {
        get;
        set;
    }

    public int count {
        get;
        set;
    }

    public DateTime? until {
        get;
        owned set;
    }

    public SimpleRecurrence (ICal.RecurrenceFrequency freq, short interval, short month_day = 0) {
        this.freq = freq;
        this.interval = interval;
        this.month_day = month_day;
        count = -1;
    }

    public string to_rrule_string () {
        var rrule_builder = new StringBuilder.sized (40);
        rrule_builder.append ("FREQ=");
        rrule_builder.append (freq.to_string ());
        if (interval > 1) {
            rrule_builder.append (";INTERVAL=%hi".printf (interval));
        }
        if (month_day != 0) {
            rrule_builder.append (";BYMONTHDAY=%hi".printf (month_day));
        }
        if (count > 0) {
            rrule_builder.append (";COUNT=%i".printf (count));
        }
        if (until != null) {
            rrule_builder.append (";UNTIL=");
            rrule_builder.append (until.format ("%Y%m%d"));
        }

        return rrule_builder.str;
    }

    public static SimpleRecurrence? from_rrule_string (string rrule_str) {
        var freq_val = ICal.RecurrenceFrequency.NO_RECURRENCE;

        // long because int.parse doesn't exist in vala 0.40
        long month_day_val = 0;
        long count_val = -1;
        ulong interval_val = 1;

        if (rrule_str == "") {
            return null;
        }

        foreach (string rrule_part in rrule_str.split (";")) {
            var key_value_pair = rrule_part.split ("=");
            if (key_value_pair[1] == null || key_value_pair[2] != null) {
                return null;
            }
            switch (key_value_pair[0]) {
                case "FREQ":
                    freq_val = ICal.RecurrenceFrequency.from_string (key_value_pair[1]);
                    break;
                case "COUNT":
                    if (long.try_parse (key_value_pair[1], out count_val)) {
                        break;
                    }
                    return null;
                case "BYMONTHDAY":
                    if (long.try_parse (key_value_pair[1], out month_day_val)) {
                        break;
                    }
                    return null;
                case "INTERVAL":
                    if (ulong.try_parse (key_value_pair[1], out interval_val)) {
                        break;
                    }
                    return null;
                default:
                    return null;
            }
        }

        switch (freq_val) {
            case ICal.RecurrenceFrequency.HOURLY_RECURRENCE:
            case ICal.RecurrenceFrequency.DAILY_RECURRENCE:
            case ICal.RecurrenceFrequency.WEEKLY_RECURRENCE:
            case ICal.RecurrenceFrequency.MONTHLY_RECURRENCE:
            case ICal.RecurrenceFrequency.YEARLY_RECURRENCE:
                break;
            default:
                return null;
        }
        var rec = new SimpleRecurrence (freq_val, (short) interval_val, (short) month_day_val);
        if (count_val > 0) {
            rec.count = (int) count_val;
        }
        return rec;
    }
}
