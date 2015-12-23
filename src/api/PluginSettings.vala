namespace GOFI.API {
    
    /**
     * A class made to restrict acces to SettingsManager for plugins.
     */
    public class PluginSettings {
        
        private SettingsManager settings;
        
        public PluginSettings (SettingsManager settings) {
            this.settings = settings;
        }
        
        public int task_duration {
            get {
                return settings.task_duration;
            }
        }
        public int break_duration {
            get {
                return settings.break_duration;
            }
        }
        public int reminder_time {
            get {
                return settings.reminder_time;
            }
        }
        public bool reminder_active {
            get {
                return settings.reminder_active;
            }
        }
    }
}
