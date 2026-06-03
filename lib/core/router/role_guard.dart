// rules_version = '2';
// service cloud.firestore {
//   match /databases/{database}/documents {

//     function isAuth() { return request.auth != null; }
//     function role() { return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role; }
//     function isUser()       { return isAuth() && role() == 'user'; }
//     function isAdmin()      { return isAuth() && role() == 'admin'; }
//     function isSuperAdmin() { return isAuth() && role() == 'superadmin'; }

//     match /users/{uid} {
//       allow read: if isAuth() && (request.auth.uid == uid || isSuperAdmin());
//       allow write: if request.auth.uid == uid || isSuperAdmin();
//     }

//     match /grounds/{groundId} {
//       allow read: if isAuth();
//       allow create: if isAdmin();
//       allow update, delete: if isAdmin() && resource.data.adminId == request.auth.uid
//                             || isSuperAdmin();
//     }

//     match /slots/{slotId} {
//       allow read: if isAuth();
//       allow write: if isAdmin() || isSuperAdmin();
//     }

//     match /bookings/{bookingId} {
//       allow read: if isAuth() && (
//         resource.data.userId == request.auth.uid ||
//         resource.data.adminId == request.auth.uid ||
//         isSuperAdmin()
//       );
//       allow create: if isUser();
//       allow update: if isSuperAdmin();
//     }

//     match /payments/{paymentId} {
//       allow read: if isAuth() && (
//         resource.data.userId == request.auth.uid || isSuperAdmin()
//       );
//       allow write: if false;  // Cloud Functions only
//     }

//     match /refundRequests/{id} {
//       allow read, create: if isUser() && resource.data.userId == request.auth.uid
//                           || isSuperAdmin();
//       allow update: if isSuperAdmin();
//     }
//   }
// }
