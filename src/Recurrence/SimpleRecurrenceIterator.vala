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
class GOFI.SimpleRecurrenceIterator : Object {
    private ICal.RecurrenceFrequency freq;
    private short interval;
    private int count;
    private int month_day;

    public DateTime current_date {
        get;
        owned set;
    }

    public DateTime? end_date {
        get;
        owned set;
    }

    public SimpleRecurrenceIterator (SimpleRecurrence rec, DateTime date) {
        freq = rec.freq;
        interval = rec.interval;
        month_day = rec.month_day;
        count = rec.count;
        end_date = rec.until;
        current_date = date;

        if (month_day == 0 || month_day < -28 || month_day > 31) {
            month_day = date.get_day_of_month ();
        }
    }

    private void fix_month_day () {
        int year, month, day;
        int desired_day;
        current_date.get_ymd (out year, out month, out day);
        var days_in_month = GLib.Date.get_days_in_month (
            (DateMonth) month, (DateYear) year
        );
        if (month_day < 0) {
            desired_day = days_in_month + month_day + 1;
        } else if (month_day > days_in_month) {
            desired_day = days_in_month;
        } else {
            desired_day = month_day;
        }
        var days_diff = desired_day - day;
        if (days_diff != 0) { // Compensating for drift.
            current_date = current_date.add_days (days_diff);
        }
    }

    private bool set_next () {
        switch (freq) {
            case ICal.RecurrenceFrequency.HOURLY_RECURRENCE:
                current_date = current_date.add_hours (interval);
                break;
            case ICal.RecurrenceFrequency.DAILY_RECURRENCE:
                current_date = current_date.add_days (interval);
                break;
            case ICal.RecurrenceFrequency.WEEKLY_RECURRENCE:
                current_date = current_date.add_weeks (interval);
                break;
            case ICal.RecurrenceFrequency.MONTHLY_RECURRENCE:
                current_date = current_date.add_months (interval);
                if (month_day < 0 || month_day > 28) {
                    fix_month_day (); // correct for possible drift
                }
                break;
            case ICal.RecurrenceFrequency.YEARLY_RECURRENCE:
                current_date = current_date.add_years (interval);
                if ((month_day < 0 || month_day > 28) && current_date.get_month () == 2) {
                    fix_month_day ();
                }
                break;
            default:
                warning ("Selected recurrence frequency %s is not supported!", freq.to_string ());
                return false;
        }
        if (end_date != null && current_date.compare (end_date) > 0) {
            return false;
        }
        return true;
    }

    public unowned DateTime? next () {
        if (count > 0) {
            count--;
        } else if (count == 0) {
            return null;
        }

        if (set_next ()) {
            return current_date;
        }
        return null;
    }

    public DateTime? next_skip_dates (DateTime cmp_date) {
        if (count > 0) {
            count--;
        } else if (count == 0) {
            return null;
        }

        set_next ();
        var diff = cmp_date.difference (current_date);
        if (diff >= 0) {
            switch (freq) {
                case ICal.RecurrenceFrequency.HOURLY_RECURRENCE:
                    int skip_span = (int) (diff / (interval * TimeSpan.HOUR));
                    current_date.add_hours (skip_span * interval);
                    break;
                case ICal.RecurrenceFrequency.DAILY_RECURRENCE:
                    int skip_span = (int) (diff / (interval * TimeSpan.DAY));
                    current_date.add_days (skip_span + 1 * interval);
                    break;
                case ICal.RecurrenceFrequency.WEEKLY_RECURRENCE:
                    int skip_span = (int) (diff / (interval * 7 * TimeSpan.DAY));
                    current_date.add_weeks (skip_span * interval);
                    break;
                default:
                    break;
            }
            while (current_date.compare (cmp_date) > 0) {
                if (!set_next ()) {
                    return null;
                }
            }
        }

        return current_date;
    }
}
