using Gtk;
using WebKit;

using GDriveSync.AuthInfo;

namespace GDriveSync.Auth {
    
    public void authenticate() {
        unowned string[] args = null;
        Gtk.init(ref args);
		
		var window = new Gtk.Window (Gtk.WindowType.TOPLEVEL);
        window.set_default_size(400,650);
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
    
    void requestToken(string code) {
        var session = new Soup.Session();
    
        var params = @"code=$(code)&";
        params += "client_id=783554179767.apps.googleusercontent.com&";
        params += "client_secret=HjHKGUiLf7JySMttK-qQe62N&";
        params += "redirect_uri=urn:ietf:wg:oauth:2.0:oob&";
        params += "grant_type=authorization_code";
        
        var message = new Soup.Message("POST", "https://accounts.google.com/o/oauth2/token");
        message.set_request("application/x-www-form-urlencoded", Soup.MemoryUse.COPY, params.data);
        session.send_message(message);
        var data = (string) message.response_body.flatten().data;
        var parser = new Json.Parser();
        parser.load_from_data (data, -1);
        var root_object = parser.get_root().get_object();
        
        access_token = root_object.get_string_member("access_token");
        expires_in = (int)root_object.get_int_member("expires_in");
        refresh_token = root_object.get_string_member("refresh_token");
    }

}
