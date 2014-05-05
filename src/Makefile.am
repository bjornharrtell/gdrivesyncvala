## Process this file with automake to produce Makefile.in

## Created by Anjuta



AM_CPPFLAGS = \
	-DPACKAGE_LOCALE_DIR=\""$(localedir)"\" \
	-DPACKAGE_SRC_DIR=\""$(srcdir)"\" \
	-DPACKAGE_DATA_DIR=\""$(pkgdatadir)"\" \
	$(GDRIVESYNC_CFLAGS)

AM_CFLAGS = -Os -s

bin_PROGRAMS = gdrivesync

gdrivesync_SOURCES = \
	gdrivesync.vala config.vapi auth.vala authinfo.vala gconf.vala localmeta.vala file.vala drivefile.vala

gdrivesync_VALAFLAGS =  \
	--pkg gtk+-3.0 --pkg webkitgtk-3.0 --pkg json-glib-1.0 --pkg gee-0.8 --pkg gconf-2.0 --pkg sqlite3


gdrivesync_LDFLAGS = \
	-Wl,--export-dynamic

gdrivesync_LDADD = $(GDRIVESYNC_LIBS)




