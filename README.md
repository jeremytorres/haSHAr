HaSHAr
---------------

The overall design goal of HaSHAr is to provide a simple-to-use file verification tool for use on Mac OSX.  File verification should:

- Utilize the latest performance-enhanced libraries within OSX, e.g., Grand Central Dispatch [(GCD)] [1] and async file I/O;
- Be based on a cryptographically-strong message digest algorithm, e.g., [SHA1] [2]
- Provide a simple, human-readable side-car file containing the hash of the file.  For example, file "MyFile.txt" would have a corresponding "MyFile.txt.sha1" side-car containing a hex-encoded string.

Other goals include:
  - Share with the open source developer community;
  - Aid in a learning opportunity;

Contact:
photog.jt@gmail.com

---

### Current Status ###

There are two (2) build targets for XCode 4:

- __CLI__: for command line execution

The CLI target is fully functional and can be use to generate/verify files based on file extensions.

- __haSHAr___: GUI control

The haSHAr GUI target is a _Work in Progress_.  This is 

See the target's respective README.md file for more information.


  [1]: http://developer.apple.com/library/mac/#documentation/Performance/Reference/GCD_libdispatch_Ref/Reference/reference.html
  [2]: http://developer.apple.com/library/mac/#documentation/Darwin/Reference/ManPages/man3/CC_SHA1.3cc.html

