/* Copyright 2015 Jonathan Moerman, Manuel Kehl (mank319)
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

class TaskView : Gtk.Stack {
    
    private TaskTimer task_timer;
    private SettingsManager settings;
    
    private Gtk.ListBox todo_list;
    private Gtk.ListBox done_list;
    private TimerView timer_view;
    
    public TaskView (TaskTimer task_timer, SettingsManager settings) {
        this.settings = settings;
        this.task_timer = task_timer;
        this.set_transition_type(
            Gtk.StackTransitionType.SLIDE_LEFT_RIGHT);
        setup_widgets ();
    }
    
    private void setup_widgets () {
        timer_view = new TimerView (task_timer);
        todo_list = new Gtk.ListBox ();
        done_list = new Gtk.ListBox ();
        
        // Add widgets to the activity stack
        this.add_titled (todo_list, "todo", _("To-Do"));
        this.add_titled (timer_view, "timer", _("Timer"));
        this.add_titled (done_list, "done", _("Done"));
        
        if (task_timer.running) {
            // Otherwise no task will be displayed in the timer view
            task_timer.update_active_task ();
            // Otherwise it won't switch
            timer_view.show ();
            this.set_visible_child_name ("timer");
        }
    }
    
    public void add_to_switcher (Gtk.StackSwitcher activity_switcher) {
        activity_switcher.set_stack (this);
    }
}
