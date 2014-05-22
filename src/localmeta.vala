using Gee;

using Sqlite;

namespace GDriveSync {

    public class LocalMeta {
        string path = Path.build_filename(Environment.get_home_dir(), CONFIGFOLDER, LOCALMETADB);
        
        Database db;
        string errmsg;

        public LocalMeta() {
            message("Opening local metadata database");
            var rc = Database.open(path, out db);

            if (rc != Sqlite.OK) {
                critical("Can't open database. Error: %s",db.errmsg ());
            }

            createschema();
        }

        void check(int err) {
            if (err != Sqlite.OK) {
                critical("Sqlite error: %s", db.errmsg());
            }
        }

        void createschema() {
            string query = """
		        CREATE TABLE localmeta (
			        path    TEXT	PRIMARY KEY		NOT NULL
		        );
		    """;
	        db.exec(query, null, out errmsg);
            query = """
                CREATE TABLE settings (
			        key     TEXT	PRIMARY KEY		NOT NULL,
                    value   TEXT	                NOT NULL
		        );
		    """;
            db.exec(query, null, out errmsg);
        }

        public void insert(string path) {
            string query = @"INSERT INTO localmeta (path) VALUES ('$(path)')";
	        check(db.exec(query, null, out errmsg));
        }

        public void remove(string path) {
            string query = @"DELETE FROM localmeta WHERE path = '$(path)'";
	        check(db.exec(query, null, out errmsg));
        }

        public void clear() {
            string query = "DELETE FROM localmeta";
	        check(db.exec(query, null, out errmsg));
        }

        public bool exists(string path) {
            string query = @"SELECT path FROM localmeta WHERE path = '$(path)'";
            //message(query);
            Sqlite.Statement stmt;
	        check(db.prepare_v2 (query, query.length, out stmt));
            var exists = stmt.step() == Sqlite.ROW;
            return exists;
        }

        public string? get(string key) {
            string query = @"SELECT value FROM settings WHERE key = '$(key)'";
            Sqlite.Statement stmt;
	        check(db.prepare_v2 (query, query.length, out stmt));
            if (stmt.step() == Sqlite.ROW) {
                return stmt.column_text(0);
            } else {
                return null;
            }
        }

        public void set(string key, string? value) {
            if (get(key) == null) {
                string query = @"INSERT INTO settings (key, value) VALUES ('$(key)', '$(value)')";
	            check(db.exec(query, null, out errmsg));
            } else {
                string query = @"UPDATE settings SET value = '$(value)' WHERE key = '$(key)'";
	            check(db.exec(query, null, out errmsg));
            }
        }
    }

}

    