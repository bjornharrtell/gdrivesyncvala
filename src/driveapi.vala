using Gee;

namespace GDriveSync.DriveAPI  {

        public File getRemoteMeta() {            
            message("Retrieve root folder metadata from Google Drive");
            var rootFolder = getRootFolder();
            message("Retrieve folders metadata from Google Drive");
            getItems(rootFolder);
            message("Determine paths");
            calcPaths(rootFolder);
            return rootFolder;
        }

        Json.Object requestJson(string url) {
            Soup.Session session = new Soup.Session();
            Json.Parser parser = new Json.Parser();
            var message = new Soup.Message("GET", url);
            session.send_message(message);
            var data = (string) message.response_body.flatten().data;
            try {
                parser.load_from_data (data, -1);
            } catch (Error e) {
                critical(e.message);
            }
            return parser.get_root().get_object();
        }

        void getItems(File folder, string? nextLink = null) {
            message("Requesting metadata for " + folder.title);

            var url = nextLink != null ? nextLink : @"https://www.googleapis.com/drive/v2/files?q=trashed+%3D+false+and+'$(folder.id)'+in+parents";
            url += @"&access_token=$(AuthInfo.access_token)";
            var json = requestJson(url);
            var items = json.get_array_member("items");

            foreach (var node in items.get_elements()) {
                var object = node.get_object();
                var item = new File();
                item.id = object.get_string_member("id");

                // NOTE: ignore items with other than 1 parent
                var parents = object.get_array_member("parents");
                if (parents.get_length() != 1) continue;

                var owners = object.get_array_member("owners");
                var isOwned = false;
                foreach (var owner in owners.get_elements()) {
                    if (owner.get_object().get_boolean_member("isAuthenticatedUser")) isOwned = true;
                }
                if (!isOwned && !notowned) continue;

                item.title = object.get_string_member("title");
                if (object.has_member("modifiedDate")) {
                    var modifiedDate = TimeVal();
                    modifiedDate.from_iso8601(object.get_string_member("modifiedDate"));
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

        File getRootFolder() {
            var url = "https://www.googleapis.com/drive/v2/about?";
            url += @"access_token=$(AuthInfo.access_token)";
            var json = requestJson(url);
            var rootFolderId = json.get_string_member("rootFolderId");
            var rootFolder = new File();
            rootFolder.id = rootFolderId;
            rootFolder.title = ROOTFOLDER;
            rootFolder.isFolder = true;            
            return rootFolder;
        }

        void calcPaths(File folder, string path = "") {
            folder.path = path + folder.title + "/";

            var newPath = output != null ? Path.build_path(Path.DIR_SEPARATOR_S, output, folder.path) : folder.path;
            debug("Create dir at " + newPath);
            try { GLib.File.new_for_path(newPath).make_directory(); } catch (Error e) {};

            foreach (var child in folder.children) {
                if (child.isFolder) {
                    calcPaths(child, folder.path);
                } else {
                    child.path = folder.path + child.title;
                }
            }
        }

        void getLocalInfo(File folder) {
            foreach (var child in folder.children) {
                var localPath = output != null ? Path.build_path(Path.DIR_SEPARATOR_S, output, child.path) : child.path;
                var file = GLib.File.new_for_path(localPath);
                try {
                    var info = file.query_info ("standard::*,time::*", FileQueryInfoFlags.NONE);
                    var type = info.get_file_type();
                    var size = info.get_size();
                    var modifiedDate = info.get_modification_time().tv_sec;
                    if (type == FileType.DIRECTORY) {
                        getLocalInfo(child);
                    } else if (type == FileType.REGULAR) {
                        //child.localFileSize = size;
                        //child.localModifiedDate = modifiedDate;
                    }
                } catch (Error e) {
                    // Failed to get local info, ignore and move on...
                }
            }
        }
        
        void download(File file) {
            message("Downloading " + file.path);

            var url_auth = file.downloadUrl + @"&access_token=$(AuthInfo.access_token)";

            Soup.Session session = new Soup.Session();
            var message = new Soup.Message("GET", url_auth);
            session.send_message(message);
            var data = message.response_body.flatten().data;

            try {
                // TODO: handle path concat with and without ending slash..
                var newPath = output != null ? Path.build_path(Path.DIR_SEPARATOR_S, output, file.path) : file.path;
                var newFile = GLib.File.new_for_path(newPath);
                var os = newFile.create(FileCreateFlags.PRIVATE | FileCreateFlags.REPLACE_DESTINATION);
                size_t bytes_written;
                os.write_all(data, out bytes_written);
                os.close();
                newFile.set_attribute_uint64(FileAttribute.TIME_MODIFIED, file.modifiedDate, 0);
            } catch (Error e) {
                critical(e.message);
            }
        }
}


