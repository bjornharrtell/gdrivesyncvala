using Gee;

namespace GDriveSync {

    public class File : GLib.Object {
        public string id { get; set; }
        public string title { get; set; }
        public bool isFolder { get; set; }
        public bool isRoot { get; set; }
        public string path { get; set; }
		
        public string downloadUrl { get; set; }
        public long modifiedDate { get; set; }
        public int64 fileSize { get; set; }

        public long syncedDate { get; set; }

        public State state { get; set; }

        public enum State {
            SYNC,
            LOCAL_NEW,
            LOCAL_CHANGED,
            LOCAL_DELETED,
            REMOTE_NEW,
            REMOTE_CHANGED,
            REMOTE_DELETED
        }
        
        public Gee.List<File> children = new ArrayList<File>();
        
        public File() {
            isRoot = true;
        }

        public void sync() {
            updateMeta();
        }
        
        public void updateMeta() {
            // populate a file tree metadata structure with google drive, local filesystem and previous sync info
            var root = DriveAPI.getRemoteMeta();
        }
    }
    
}