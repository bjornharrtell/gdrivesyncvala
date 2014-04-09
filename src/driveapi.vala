using Gee;

namespace GDriveSync {

    class DriveAPI : GLib.Object {     
        
        class Item : GLib.Object {
            public string id;
            public string title;
            public bool isFolder;
            public string path;
            public string downloadUrl;
            public long modifiedDate;
            public int64 fileSize;

            public long localModifiedDate;
            public int64 localFileSize;

            public Gee.List<Item> children;

            public Item() {
                children = new ArrayList<Item>();
                localModifiedDate = 0;
            }
        }
        
        Soup.Session session = new Soup.Session();
        Json.Parser parser = new Json.Parser();

        Json.Object requestJson(string url) {
            var message = new Soup.Message("GET", url);
            session.send_message(message);
            var data = (string) message.response_body.flatten().data;
            //debug("Got response from Google Drive API");
		    //debug(data + "\n");
            try {
                parser.load_from_data (data, -1);
            } catch (Error e) {
                critical(e.message);
            }
            return parser.get_root().get_object();
        }

        void getItems(Item folder, string? nextLink = null) {
            debug("Processing folder: " + folder.title);

            var url = nextLink != null ? nextLink : @"https://www.googleapis.com/drive/v2/files?q=trashed+%3D+false+and+'$(folder.id)'+in+parents";
            url += @"&access_token=$(AuthInfo.access_token)";
            var json = requestJson(url);
            var items = json.get_array_member("items");
            
            foreach (var node in items.get_elements()) {
                var object = node.get_object();
                var item = new Item();
                item.id = object.get_string_member("id");
                var parents = object.get_array_member("parents");
                // NOTE: ignore items with other than 1 parent
                if (parents.get_length() != 1) continue;
                item.title = object.get_string_member("title");
                //var modifiedDate = object.get_string_member("modifiedDate");
                if (object.has_member("fileSize")) {
                    var modifiedDate = new TimeVal();
                    var modifiedDateISO = object.get_string_member("modifiedDate");
                    modifiedDate.from_iso8601(modifiedDateISO);
                    item.modifiedDate = modifiedDate.tv_sec;
                }
                item.fileSize = object.has_member("fileSize") ? (int64) object.get_int_member("fileSize") : 0;
                item.downloadUrl = object.has_member("downloadUrl") ? object.get_string_member("downloadUrl") : null;
                var mimeType = object.get_string_member("mimeType");
                item.isFolder = mimeType == "application/vnd.google-apps.folder";
                folder.children.add(item);
                if (item.isFolder) getItems(item);
            }
        
            var next = json.has_member("nextLink") && !json.get_null_member("nextLink") ? json.get_string_member("nextLink") : null;
            if (next != null) getItems(folder, next);
        }

        Item getRootFolder() {
            var url = "https://www.googleapis.com/drive/v2/about?";
            url += @"access_token=$(AuthInfo.access_token)";
            var json = requestJson(url);
            var rootFolderId = json.get_string_member("rootFolderId");
            var rootFolder = new Item();
            rootFolder.id = rootFolderId;
            rootFolder.title = "Google Drive";
            rootFolder.isFolder = true;

            debug("Root folder ID: " + rootFolderId);
            
            return rootFolder;
        }

        void processFiles(Item folder, string path = "") {
            folder.path = path + folder.title + "/";

            debug("Create directory at: " + folder.path);

            try { File.new_for_path(folder.path).make_directory(); } catch (Error e) {};
                        
            foreach (var child in folder.children) {
                if (child.isFolder) {
                    processFiles(child, folder.path);
                } else {
                    child.path = folder.path + child.title;
                }
            }
        }

        void syncFiles(Item folder) {
            foreach (var child in folder.children) {
                if (child.isFolder) {
                    syncFiles(child);
                } else if (child.downloadUrl != null) {
                    if (
                        child.modifiedDate > child.localModifiedDate) {
                        debug("Remote file newer or local file missing, will download");
                        //debug("Modified date %lu", child.modifiedDate);
                        //debug("Local modified date %lu", child.localModifiedDate);
                        download(child);
                    } else {
                        debug("Remote file older or same, skip download");
                    }
                }
            }
        }

        void getLocalInfo(Item folder) {
            foreach (var child in folder.children) {
                //debug("Getting local info for " + child.path);
                File file = File.new_for_path(child.path);
                try {
                    FileInfo info = file.query_info ("standard::*,time::*", FileQueryInfoFlags.NONE);
                    var type = info.get_file_type();
                    var size = info.get_size();
                    var modifiedDate = info.get_modification_time().tv_sec;
                    if (type == FileType.DIRECTORY) {
                        getLocalInfo(child);
                    } else if (type == FileType.REGULAR) {
                        child.localFileSize = size;
                        child.localModifiedDate = modifiedDate;
                    }
                } catch (Error e) {
                    // debug(e.message);
                    // Failed to get local info, ignore and move on...
                }
            }
        }
        
        public void getFiles() {
            var rootFolder = getRootFolder();
            getItems(rootFolder);
            processFiles(rootFolder);
            getLocalInfo(rootFolder);
            syncFiles(rootFolder);
        }

        void download(Item item) {
            debug("Download file to: " + item.path);

            var url_auth = item.downloadUrl + @"&access_token=$(AuthInfo.access_token)";
            
            var message = new Soup.Message("GET", url_auth);
            session.send_message(message);
            var data = message.response_body.flatten().data;

            try {
                var newFile = File.new_for_path(item.path);
                var os = newFile.create(FileCreateFlags.PRIVATE | FileCreateFlags.REPLACE_DESTINATION);
                size_t bytes_written;
                os.write_all(data, out bytes_written);
                os.close();
                //debug("Set TIME_MODIFIED to: %lu", item.modifiedDate);
                newFile.set_attribute_uint64(FileAttribute.TIME_MODIFIED, item.modifiedDate, 0);
            } catch (Error e) {
                critical(e.message);
            }
        }
    }

}
