using GDriveSync.AuthInfo;
using GConf;

namespace GDriveSync.GConf  {

    const string access_token_key = "/apps/gdrivesync/auth/access_token";
    const string refresh_token_key = "/apps/gdrivesync/auth/refresh_token";
    const string expires_in_key = "/apps/gdrivesync/auth/expires_in";
    const string issued_key = "/apps/gdrivesync/auth/issued";

    public void persist() {
        debug("Persisting AuthInfo with GConf");
        var gc = Client.get_default();
        try {
            gc.set_string(refresh_token_key, refresh_token);
            gc.set_string(access_token_key, access_token);
            gc.set_int(expires_in_key, (int) expires_in);
            gc.set_int(issued_key, (int) issued);
        } catch (GLib.Error e) {
            critical(e.message);
        }
    }

    public void read() {
        debug("Reading AuthInfo with GConf");
        var gc = Client.get_default();
        try {
            refresh_token = gc.get_string(refresh_token_key);
            access_token = gc.get_string(access_token_key);
            expires_in = (int64) gc.get_int(expires_in_key);
            issued = (int64) gc.get_int(issued_key);
        } catch (GLib.Error e) {
            critical(e.message);
        }
    }
}
