/* Copyright 2021 GoForIt! developers
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
public class GOFI.RecurrenceRule : Object {
    public GOFI.RecurrenceFrequency freq {
        get;
        set;
        default = GOFI.RecurrenceFrequency.DAILY_RECURRENCE;
    }

    public short interval {
        get;
        set;
        default = 1;
    }

    /**
     * Used to specify the day of the month for monthly and yearly recurring tasks.
     *
     * Negative values can be used to repeat relative to the end of a month.
     * For example, a recurrence rule that repeats every month with a month_day
     * of -2 would results in an occurence every month on the second to last day.
     * If set to 0 and the task recurs on a monthly or yearly basis, the day may
     * drift a bit. For example, if a task repeats every month and a new task is
     * scheduled using the following previous date: 2021-01-31, the new date
     * will be 2021-02-28. When this process is repeated the next date would be
     * 2021-03-28. If set to 31 or -1 the sequence of dates would be
     * 2021-01-31 -> 2021-02-28 -> 2021-03-31.
     */
    public short month_day {
        get;
        set;
        default = 0;
    }

    public int count {
        get;
        set;
        default = -1;
    }

    public DateTime? until {
        get;
        owned set;
        default = null;
    }

    public RecurrenceRule (GOFI.RecurrenceFrequency freq, short interval, short month_day = 0) {
        this.freq = freq;
        this.interval = interval;
        this.month_day = month_day;
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
}
