require 'formula'

class Qwt < Formula
  homepage 'http://qwt.sourceforge.net/'
  url 'http://downloads.sourceforge.net/project/qwt/qwt/6.1.0/qwt-6.1.0.tar.bz2'
  sha1 '48a967038f7aa9a9c87c64bcb2eb07c5df375565'

  option "without-framework", "Build as libs instead of framework"
  option "with-qwtmathml", "Build the qwtmathml library"

  depends_on 'qt'

  # update designer plugin linking back to qwt framework/lib
  # this is specific to Homebrew and probably (?) doesn't need patched upstream
  def patches
    DATA
  end

  def install
    inreplace 'qwtconfig.pri' do |s|
      # change_make_var won't work because there are leading spaces
      s.gsub! /^\s*QWT_INSTALL_PREFIX\s*=(.*)$/, "QWT_INSTALL_PREFIX=#{prefix}"
      s.sub! /#(QWT_CONFIG\s*\+= QwtMathML)/, "\\1" if build.with? "qwtmathml"
      s << "\n" << "QWT_CONFIG -= QwtFramework" if build.without? "framework"
    end

    args = %W[-config release -spec]
    # On Mavericks we want to target libc++, this requires a unsupported/macx-clang-libc++ flag
    if ENV.compiler == :clang and MacOS.version >= :mavericks
      args << "unsupported/macx-clang-libc++"
    else
      args << "macx-g++"
    end
    system 'qmake', *args
    system "make"
    system "make install"

    # symlink Qt Designer plugin (note: not removed on qwt formula uninstall)
    cd Formula.factory("qt").opt_prefix/"plugins/designer" do
      ln_sf prefix/"plugins/designer/libqwt_designer_plugin.dylib", "."
    end
  end

  def caveats
    if build.with? "qwtmathml";<<-EOS.undent
        The qwtmathml library contains code of the MML Widget from the Qt solutions package.
        Beside the Qwt license you also have to take care of its license.
      EOS
    end
  end
end

__END__
diff --git a/designer/designer.pro b/designer/designer.pro
index c269e9d..5c333fd 100644
--- a/designer/designer.pro
+++ b/designer/designer.pro
@@ -126,6 +126,15 @@ contains(QWT_CONFIG, QwtDesigner) {

     target.path = $${QWT_INSTALL_PLUGINS}
     INSTALLS += target
+    macx {
+        contains(QWT_CONFIG, QwtFramework) {
+            QWT_LIB = qwt.framework/Versions/$${QWT_VER_MAJ}/qwt
+        }
+        else {
+            QWT_LIB = libqwt.$${QWT_VER_MAJ}.dylib
+        }
+        install_name_tool -change $${QWT_LIB} $${QWT_INSTALL_PREFIX}/lib/$${QWT_LIB} ${DESTDIR}/$(TARGET)
+    }
 }
 else {
     TEMPLATE        = subdirs # do nothing
