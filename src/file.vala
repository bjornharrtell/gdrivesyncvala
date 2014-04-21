using Gee;

namespace GDriveSync {

    public class File : GLib.Object {
        public string id { get; set; }
        public bool remoteExists { get; set; }
        public string title { get; set; }
        public bool isFolder { get; set; }
        public bool isRoot { get; set; }
        public string path { get; set; }
		
        public string downloadUrl { get; set; }
        public long modifiedDate { get; set; }
        public string MD5 { get; set; }

        public bool wasSynced { get; set; }
        public bool localExists { get; set; }
        public string localMD5 { get; set; }
        
        public HashMap<string, File> children = new HashMap<string, File>();

        public File() {
        }
        
        public File.as_root() {
            isRoot = true;
            isFolder = true;
            path = "";
        }

        public void sync() {
            fetchLocalMeta(this);
            // TODO: add local metadata (
            // LocalDB.fetchMeta(this);
            DriveAPI.fetchMeta(this);
            doSync(this);
        }

        static void doSync(File file) {

            // TODO: need to rethink this logic.. to make it as small and sane as possible
            
            if (file.isFolder) {
                // TODO: should handle deletes and remote creation too
                file.createDir();
            } else if (!file.remoteExists && file.wasSynced) {
                // file exists locally and was synced with remote but it longer exists remotely, delete it locally
                file.remove();
            } else if (!file.remoteExists && !file.wasSynced) {
                // file exist locally and hasn't been synced before and does not exist remotely, upload
                DriveAPI.upload(file);
            } else if (file.remoteExists && !file.wasSynced) {
                // file exists remotely and has not been synced before, download
                DriveAPI.download(file);
            } else if (file.remoteExists && file.wasSynced && !file.localExists) {
                // file exists remotely, has been synced before but no longer exists locally, delete it remotely
                DriveAPI.remove(file);
            }

            foreach (var child in file.children.values) {
                doSync(child);
            }
        }

        public void createDir() {
            if (isFolder) {
                try { getLocalFile().make_directory(); } catch (Error e) {};
            }
        }

        public void remove() {
           getLocalFile().delete();
           // TODO: also remove persisted data
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
                file.localExists = true;
                
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
            var localPath = Path.build_filename(output, path);
            return GLib.File.new_for_path(localPath);
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