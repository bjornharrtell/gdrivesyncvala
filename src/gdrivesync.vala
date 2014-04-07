using GDriveSync.AuthInfo;

namespace GDriveSync {

    class GDriveSync : GLib.Object {

        public static int main(string[] args) {

            if (access_token == null) {
			    debug("No previous access token found, will try to get authorization.");
                Auth.authenticate();
                DriveAPI.getFiles();
            } else {
			    debug("Access token %s found.", access_token);
                DriveAPI.getFiles();
            }

            return 0;
        } 
    }

}