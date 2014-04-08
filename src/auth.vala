using Gtk;
using WebKit;

using GDriveSync;

namespace GDriveSync.Auth {

    void doFullAuth() {
        unowned string[] args = null;
        Gtk.init(ref args);

        var window = new Gtk.Window (Gtk.WindowType.TOPLEVEL);
        window.set_default_size(400, 650);
        window.set_position(Gtk.WindowPosition.CENTER);
        window.title = "GDriveSync";
        window.destroy.connect(Gtk.main_quit);

        var webView = new WebView();

        window.add(webView);

        var uri = "https://accounts.google.com/o/oauth2/auth?response_type=code&client_id=783554179767.apps.googleusercontent.com&redirect_uri=urn:ietf:wg:oauth:2.0:oob&scope=https://www.googleapis.com/auth/drive";

        webView.load_finished.connect( (webView, load_event) => {
            var title = webView.get_title();
            if (title != null) {
                var split = title.split("=");
                if (split.length == 2 && split[0] == "Success code") {
                    var code = split[1];
                    window.close();
                    requestToken(code);
                }
            }
        });

        webView.show();
        window.show();

        webView.load_uri(uri);

        Gtk.main();
    }

    /**
     * Get valid Google API authentication
     * Tries the following:
     * 1. Check if already got valid auth, if so do nothing
     * 2. Read from GConf, repeat step 1.
     * 3. Refresh auth using refresh token if exist
     * 4. Do full authentication (will prompt for login and access grant)
     **/
    public void authenticate() {
        debug("Requesting/checking authorization");
        if (!AuthInfo.hasValidAccessToken()) {
            GConf.read();
            if (!AuthInfo.hasValidAccessToken()) {
                if (AuthInfo.refresh_token != null) {
                    refreshToken();
                } else {
                    doFullAuth();
                }
            }
        }
    }

    Json.Object request(string params) {
        var session = new Soup.Session();
        var message = new Soup.Message("POST", "https://accounts.google.com/o/oauth2/token");
        message.set_request("application/x-www-form-urlencoded", Soup.MemoryUse.COPY, params.data);
        session.send_message(message);
        var data = (string) message.response_body.flatten().data;
        var parser = new Json.Parser();
        try {
            parser.load_from_data (data, -1);
        } catch (Error e) {
            critical(e.message);
        }
        var object = parser.get_root().get_object();
        return object;
    }

    void requestToken(string code) {
        debug("Attempting get new access token from authorization code");

        var params = @"code=$(code)&";
        params += "client_id=783554179767.apps.googleusercontent.com&";
        params += "client_secret=HjHKGUiLf7JySMttK-qQe62N&";
        params += "redirect_uri=urn:ietf:wg:oauth:2.0:oob&";
        params += "grant_type=authorization_code";

        var object = request(params);

        AuthInfo.access_token = object.get_string_member("access_token");
        AuthInfo.expires_in = object.get_int_member("expires_in");
        AuthInfo.refresh_token = object.get_string_member("refresh_token");
        AuthInfo.issued = new DateTime.now_local().to_unix();

        GConf.persist();
    }

    void refreshToken() {
        debug("Attempting to use refresh token to get new access token");

        var params = "client_id=783554179767.apps.googleusercontent.com&";
        params += "client_secret=HjHKGUiLf7JySMttK-qQe62N&";
        params += @"refresh_token=$(AuthInfo.refresh_token)&";
        params += "grant_type=refresh_token";

        var object = request(params);

        AuthInfo.access_token = object.get_string_member("access_token");
        AuthInfo.expires_in = object.get_int_member("expires_in");
        AuthInfo.issued = new DateTime.now_local().to_unix();

        GConf.persist();
    }

}
