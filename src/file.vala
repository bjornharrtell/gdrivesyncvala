using Gee;

namespace GDriveSync {

    public abstract class File : GLib.Object {
        public string id { get; set; }
        public bool remoteExists { get; set; }
        public string title { get; set; }
        public bool isFolder { get; set; }
        public bool isRoot { get; set; }
        public string path { get; set; }

        public bool wasSynced { get; set; }
        public bool localExists { get; set; }
        public int64 localFileSize { get; set; }
        public long localModifiedDate { get; set; }
        public string localMD5 { get; set; }

        protected static LocalMeta localMeta = new LocalMeta();
                
        public void createDir() {
            if (isFolder) {
                try { getLocalFile().make_directory(); } catch (Error e) {};
            }
        }

        public void delete() {
           message("Deleting local file: " + path);
           getLocalFile().delete();
           localMeta.remove(path);
        }
        
        public string getAbsPath() {
            var localPath = Path.build_filename(output, path);
            return localPath;
        }

        public GLib.File getLocalFile() {
            var localPath = getAbsPath();
            return GLib.File.new_for_path(localPath);
        }

        public FileInfo queryInfo() {
            var file = getLocalFile();
            return file.query_info ("standard::*,time::*", FileQueryInfoFlags.NONE);
        }
        
        public string calcLocalMD5() {
            var file = getLocalFile();
            var checksum = new Checksum(ChecksumType.MD5);
            var stream = file.read();
	        uint8 fbuf[1024];
	        size_t size;

	        while ((size = stream.read (fbuf)) > 0) {
		        checksum.update(fbuf, size);
	        }

	        unowned string digest = checksum.get_string ();
	        return digest;
        }
    }
    
}