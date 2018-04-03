// this code comments out the CODE_SIGN_ENTITLEMENTS setting in the build.xcconfig
// in order to get rid of following build process warning: "Falling back to contents of entitlements file "Entitlements-Debug.plist" because it was modified during the build process. Modifying the entitlements file during the build is unsupported.error: The file “Entitlements-Debug.plist” couldn’t be opened because there is no such file.""
var fs = require('fs');
var xcconfigFile = 'platforms/ios/cordova/build.xcconfig';
var text = fs.readFileSync(xcconfigFile, 'utf-8');
var idx = text.search(/^\s?CODE_SIGN_ENTITLEMENTS/gm);
if (idx != -1) {
    var newText = text.slice(0, idx) + "// [this line was commented out automatically by MobileMessagingCordova plugin hook due to a Cordova issue CB-12212] " + text.slice(idx);
    fs.writeFileSync(xcconfigFile, newText, 'utf-8');
}
// The CocoaPods plugin framework path incorrectly gets malformed with the redundant inclusion of 'Pods' directory. Fix for this is to add a symlink.
fs.symlink('../Pods', './platforms/ios/Pods/Pods', 'dir', function (err) {
    if (err) {
      console.log(
        err.code === 'EEXIST' ? "Link already created!\n" : "Error\n"
      );
      console.log(err);
    }
  });
