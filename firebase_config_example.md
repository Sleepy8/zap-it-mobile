# Firebase Configuration for Zap It

## Firebase Storage Rules

Add these rules to your Firebase Storage to allow image uploads:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Allow authenticated users to upload profile images
    match /profile_images/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Allow authenticated users to upload any image in their folder
    match /profile_images/{userId}/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## Firebase Firestore Rules

Add these rules to your Firestore to secure user data:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Friendships collection
    match /friendships/{friendshipId} {
      allow read, write: if request.auth != null;
    }
    
    // Zaps collection
    match /zaps/{zapId} {
      allow read, write: if request.auth != null;
    }
    
    // Conversations collection
    match /conversations/{conversationId} {
      allow read, write: if request.auth != null && 
        request.auth.uid in resource.data.participants;
    }
    
    // Messages subcollection
    match /conversations/{conversationId}/messages/{messageId} {
      allow read, write: if request.auth != null && 
        request.auth.uid in get(/databases/$(database)/documents/conversations/$(conversationId)).data.participants;
    }
  }
}
```

## Setup Instructions

1. **Firebase Console**: Go to your Firebase project
2. **Storage**: Navigate to Storage > Rules and paste the storage rules
3. **Firestore**: Navigate to Firestore > Rules and paste the firestore rules
4. **Publish**: Click "Publish" to activate the rules

## Troubleshooting

If you still get upload errors:
1. Check that your Firebase project has Storage enabled
2. Verify the rules are published
3. Ensure the user is authenticated before upload
4. Check the Firebase console logs for specific error messages 