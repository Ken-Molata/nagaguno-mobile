# google_mlkit_face_detection references an optional Firebase class
# (com.google.firebase.iid.FirebaseInstanceId) on a code path this app
# never exercises -- no Firebase dependency is included at all, by
# design. R8 fails the release build outright over the missing class
# unless told to stop warning about it; this is the exact line R8's
# own missing_rules.txt generated for this build.
-dontwarn com.google.firebase.iid.FirebaseInstanceId
