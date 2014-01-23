require "formula"

class Qwtpolar < Formula
  homepage "http://qwtpolar.sourceforge.net/"
  url "http://downloads.sf.net/project/qwtpolar/qwtpolar-beta/1.1.0-rc1/qwtpolar-1.1.0-rc1.tar.bz2"
  sha1 "b71d6f462c857fd57f295ad97e87efa88b3b1ada"

  option "without-framework", "Build as libs instead of framework"
  option "with-examples", "Build example apps"

  depends_on "qt"
  depends_on "qwt"

  # update designer plugin linking back to qwtpolar framework/lib
  def patches
    DATA
  end

  def install
    qwt = Formula.factory("qwt")
    qwt_lib = qwt.opt_prefix/"lib"
    inreplace "qwtpolarconfig.pri" do |s|
      # change_make_var won't work because there are leading spaces
      s.gsub! /^(\s*)QWT_POLAR_INSTALL_PREFIX\s*=\s*(.*)$/, "\\1QWT_POLAR_INSTALL_PREFIX=#{prefix}"
      s.sub! /(QWT_POLAR_CONFIG\s*\+= QwtPolarExamples)/, "#\\1" unless build.with? "examples"
      s << "\n" << "QWT_POLAR_CONFIG -= QwtPolarFramework" if build.without? "framework"
      # add paths to installed qwt
      if File.exists? "#{qwt_lib}/qwt.framework"
        s << "\n" << "INCLUDEPATH += #{qwt_lib}/qwt.framework/Headers"
        s << "\n" << "QMAKE_LFLAGS += -F#{qwt_lib}/"
        s << "\n" << "LIBS += -framework qwt"
      else
        s << "\n" << "INCLUDEPATH += #{qwt.opt_prefix}/include"
        s << "\n" << "QMAKE_LFLAGS += -L#{qwt_lib}/"
        s << "\n" << "LIBS += -lqwt"
      end
    end

    inreplace "designer/designer.pro" do |s|
      # qwtpolar can be built as framework or lib independent of qwt's install type
      s.gsub! "QWT_CONFIG, QwtFramework", "QWT_POLAR_CONFIG, QwtPolarFramework"
    end

    inreplace "examples/examples.pri" do |s|
      # this looks like a typo, and should be reported upstream
      s.gsub! "QWT_CONFIG, QwtPolarFramework", "QWT_POLAR_CONFIG, QwtPolarFramework"
    end if build.with? "examples"

    args = %W[-config release -spec]
    # On Mavericks we want to target libc++, this requires a unsupported/macx-clang-libc++ flag
    if ENV.compiler == :clang and MacOS.version >= :mavericks
      args << "unsupported/macx-clang-libc++"
    else
      args << "macx-g++"
    end

    system "qmake", *args
    system "make"
    system "make", "install"

    # symlink Qt Designer plugin (note: not removed on qwtpolar formula uninstall)
    cd Formula.factory("qt").opt_prefix/"plugins/designer" do
      ln_sf prefix/"plugins/designer/libqwt_polar_designer_plugin.dylib", "."
    end
  end

end

__END__
diff --git a/designer/designer.pro b/designer/designer.pro
index 4bca34c..208c428 100644
--- a/designer/designer.pro
+++ b/designer/designer.pro
@@ -58,6 +58,15 @@ contains(QWT_POLAR_CONFIG, QwtPolarDesigner) {

     target.path = $${QWT_POLAR_INSTALL_PLUGINS}
     INSTALLS += target
+    macx {
+        contains(QWT_POLAR_CONFIG, QwtPolarFramework) {
+            QWTP_LIB = qwtpolar.framework/Versions/$${QWT_POLAR_VER_MAJ}/qwtpolar
+        }
+        else {
+            QWTP_LIB = libqwtpolar.$${QWT_POLAR_VER_MAJ}.dylib
+        }
+        QMAKE_POST_LINK = install_name_tool -change $${QWTP_LIB} $${QWT_POLAR_INSTALL_PREFIX}/lib/$${QWTP_LIB} ${DESTDIR}/$(TARGET)
+    }
 }
 else {
     TEMPLATE        = subdirs # do nothing
