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
        public string MD5 { get; set; }

        public long lastSyncedDate { get; set; }
        public string localMD5 { get; set; }
        
        public State state { get; set; }

        // possible states.. move to internal logic in doSync
        public enum State {
            SYNC,
            LOCAL_NEW,
            LOCAL_CHANGED,
            LOCAL_DELETED,
            REMOTE_NEW,
            REMOTE_CHANGED,
            REMOTE_DELETED
        }
        
        public HashMap<string, File> children = new HashMap<string, File>();

        public File() {
        }
        
        public File.as_root() {
            isRoot = true;
            isFolder = true;
            path = "";
        }

        public void sync() {
            // populate with local file meta
            fetchLocalMeta(this);
            // add persisted meta (file path, last synced date)
            // LocalDB.fetchMeta(this);
            // add remote meta
            //DriveAPI.fetchMeta(this);
            doSync();
            
        }

        void doSync() {
            // TODO: do appropriate action depending on state
            // persist last synced date on download/upload!
            // remove data from persistance if delete
        }

        void createDir() {
            if (isFolder) {
                var newPath = Path.build_filename(output, path);
                try { GLib.File.new_for_path(newPath).make_directory(); } catch (Error e) {};
            }
        }

        public static void fetchLocalMeta(File folder) {
            folder.createDir();

            var localPath = Path.build_filename(output, folder.path);

            var dir = Dir.open(localPath);
            string? name = null;
            while ((name = dir.read_name ()) != null) {
                var relativePath = Path.build_filename(folder.path, name);

                var file = new File();
                file.path = relativePath;
                
                FileInfo info = file.queryInfo();
                var type = info.get_file_type();
                var size = info.get_size();
                var modifiedDate = info.get_modification_time().tv_sec;
                if (type == FileType.DIRECTORY) {
                    file.isFolder = true;
                    fetchLocalMeta(file);
                } else if (type == FileType.REGULAR) {
                    file.isFolder = false;
                    file.localMD5 = file.calcLocalMD5();
                }
                folder.children.set(name, file);
            }
        }

        GLib.File getLocalFile() {
            var localPath = output != null ? Path.build_filename(output, path) : path;
            return GLib.File.new_for_path(localPath);
        }

        public bool queryExistsLocally() {
	        return getLocalFile().query_exists();
        }

        FileInfo queryInfo() {
            var file = getLocalFile();
            return file.query_info ("standard::*,time::*", FileQueryInfoFlags.NONE);
        }
        
        public string calcLocalMD5() {
            var file = getLocalFile();
            var checksum = new Checksum(ChecksumType.MD5);
            var stream = file.read();
	        uint8 fbuf[100];
	        size_t size;

	        while ((size = stream.read (fbuf)) > 0) {
		        checksum.update(fbuf, size);
	        }

	        unowned string digest = checksum.get_string ();
	        return digest;
        }
    }
    
}