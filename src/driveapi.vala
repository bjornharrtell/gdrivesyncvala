using Gee;

namespace GDriveSync.DriveAPI  {

    public void fetchMeta(File root) {            
        message("Retrieve root folder metadata from Google Drive");
        fetchRootFolderMeta(root);
        message("Retrieve all folders metadata from Google Drive");
        getItemsMeta(root);
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

    File parseItem(Json.Node node) {
        var object = node.get_object();
        var file = new File();
        file.id = object.get_string_member("id");

        // NOTE: ignore items with other than 1 parent
        var parents = object.get_array_member("parents");
        if (parents.get_length() != 1) return null;

        var owners = object.get_array_member("owners");
        var isOwned = false;
        foreach (var owner in owners.get_elements()) {
            if (owner.get_object().get_boolean_member("isAuthenticatedUser")) isOwned = true;
        }
        if (!isOwned && !notowned) return null;

        file.title = object.get_string_member("title");
        if (object.has_member("modifiedDate")) {
            var modifiedDate = TimeVal();
            modifiedDate.from_iso8601(object.get_string_member("modifiedDate"));
            file.modifiedDate = modifiedDate.tv_sec;
        }
        //file.fileSize = object.has_member("fileSize") ? (int64) object.get_int_member("fileSize") : 0;
        file.downloadUrl = object.has_member("downloadUrl") ? object.get_string_member("downloadUrl") : null;

        var mimeType = object.get_string_member("mimeType");
        file.isFolder = mimeType == "application/vnd.google-apps.folder";

        return file;
    }
    
    void getItemsMeta(File folder, string? nextLink = null) {
        message("Requesting metadata for " + folder.title);

        var url = nextLink != null ? nextLink : @"https://www.googleapis.com/drive/v2/files?q=trashed+%3D+false+and+'$(folder.id)'+in+parents";
        url += @"&access_token=$(AuthInfo.access_token)";
        var json = requestJson(url);
        var items = json.get_array_member("items");

        foreach (var node in items.get_elements()) {
            var file = parseItem(node);
            if (file != null) {
                file.path = folder.path + file.title;
                folder.children.set(file.title, file);
                if (file.isFolder) {
                    file.path = file.path + "/";
                    getItemsMeta(file);
                }
            }
        }

        var next = json.has_member("nextLink") && !json.get_null_member("nextLink") ? json.get_string_member("nextLink") : null;
        if (next != null) getItemsMeta(folder, next);
    }

    void fetchRootFolderMeta(File root) {
        var url = "https://www.googleapis.com/drive/v2/about?";
        url += @"access_token=$(AuthInfo.access_token)";
        var json = requestJson(url);
        var rootFolderId = json.get_string_member("rootFolderId");
        root.id = rootFolderId;
        root.title = ROOTFOLDER;
        root.path = "";
        root.isFolder = true;
        root.isRoot = true;
        root.state = File.State.REMOTE_NEW;
    }

    void download(File file) {
        message("Downloading " + file.path);

        var url_auth = file.downloadUrl + @"&access_token=$(AuthInfo.access_token)";

        Soup.Session session = new Soup.Session();
        var message = new Soup.Message("GET", url_auth);
        session.send_message(message);
        var data = message.response_body.flatten().data;

        try {
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


