using GConf;

class GDriveSync : GLib.Object {

    Client gc = Client.get_default();
    string root = "/apps/gdrivesync";
    string access_token_key = "/apps/gdrivesync/auth/access_token";
    string access_token;
     
    public static int main(string[] args) {
        var gdrivesync = new GDriveSync();      
        gdrivesync.run(args);
		
        return 0;
    }
    
    public void run(string[] args) {
        access_token = gc.get_string(access_token_key);
    
        if (access_token == null) {
            var auth = new Auth();
            var tokenInfo = auth.getTokenInfo(args);
            access_token = tokenInfo.access_token;
            gc.set_string(access_token_key, access_token);
            DriveAPI.getFiles(access_token);
        } else {
            DriveAPI.getFiles(access_token);
        }
    }   
}
