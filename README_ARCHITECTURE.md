# WorkConnect - Mobile App Architecture & Documentation

## 📱 App Overview

WorkConnect is a mobile application similar to Uber, but instead of drivers, it connects customers with local workers such as plumbers, electricians, mechanics, and technicians.

## 🏗️ Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                       │
├─────────────────────────────────────────────────────────────┤
│  UI Components  │  Screens  │  Widgets  │  State Management │
│    - Auth UI    │  - Login  │  - Rating │     - Provider    │
│   - Review UI   │  - Home   │  - Cards  │                   │
│   - Job UI      │  - Jobs   │  - Forms  │                   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     BUSINESS LAYER                          │
├─────────────────────────────────────────────────────────────┤
│             Repositories & Use Cases                        │
│  - AuthRepository    │  - ReviewRepository                  │
│  - JobRepository     │  - WorkerRepository                  │
│  - UserRepository    │  - LocationRepository                │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      DATA LAYER                             │
├─────────────────────────────────────────────────────────────┤
│  Models  │     Firebase Services      │  External APIs      │
│ - User   │  - Authentication          │ - Google Maps      │
│ - Worker │  - Firestore Database      │ - Geocoding        │
│ - Job    │  - Cloud Storage           │ - Push Notifications│
│ - Review │  - Cloud Functions         │                    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    FIREBASE BACKEND                         │
├─────────────────────────────────────────────────────────────┤
│ Authentication │ Firestore │ Cloud Functions │ Storage     │
│   - Email      │ - Users   │  - Rating Calc  │ - Images    │
│   - Phone      │ - Jobs    │  - Notifications│ - Documents │
│   - Google     │ - Reviews │  - Validation   │             │
└─────────────────────────────────────────────────────────────┘
```

## 📁 Flutter Project Structure

```
lib/
├── core/
│   ├── constants/
│   │   └── app_constants.dart
│   ├── utils/
│   │   ├── validators.dart
│   │   └── helpers.dart
│   └── errors/
│       └── exceptions.dart
├── data/
│   ├── models/
│   │   ├── user_model.dart
│   │   ├── worker_model.dart
│   │   ├── job_model.dart
│   │   └── review_model.dart
│   ├── repositories/
│   │   ├── auth_repository.dart
│   │   ├── review_repository.dart
│   │   ├── job_repository.dart
│   │   └── worker_repository.dart
│   └── datasources/
│       ├── firebase_datasource.dart
│       └── location_datasource.dart
├── features/
│   ├── authentication/
│   │   ├── data/
│   │   └── presentation/
│   │       ├── pages/
│   │       │   ├── auth_wrapper.dart
│   │       │   └── login_screen.dart
│   │       └── widgets/
│   ├── jobs/
│   │   ├── data/
│   │   └── presentation/
│   │       ├── pages/
│   │       └── widgets/
│   ├── reviews/
│   │   ├── data/
│   │   └── presentation/
│   │       └── submit_review_screen.dart
│   └── worker/
│       ├── data/
│       └── presentation/
└── shared/
    └── widgets/
        ├── star_rating_widget.dart
        └── review_widgets.dart
```

## 🗄️ Firestore Database Schema

### Collections Structure

#### 1. Users Collection
```javascript
users/{userId}
{
  name: string,
  email: string,
  phone: string,
  role: "customer" | "worker" | "admin",
  profileImageUrl?: string,
  createdAt: timestamp,
  updatedAt: timestamp
}
```

#### 2. Workers Collection
```javascript
workers/{workerId}
{
  userId: string,
  skills: string[],
  bio: string,
  hourlyRate: number,
  isOnline: boolean,
  location?: GeoPoint,
  address?: string,
  certificationImages: string[],
  isVerified: boolean,
  totalJobs: number,
  avgRating: number,
  ratingCount: number,
  createdAt: timestamp,
  updatedAt: timestamp
}
```

#### 3. Jobs Collection
```javascript
jobs/{jobId}
{
  customerId: string,
  workerId?: string,
  serviceType: string,
  description: string,
  location: GeoPoint,
  address: string,
  status: "requested" | "accepted" | "in_progress" | "completed" | "cancelled",
  agreedPrice?: number,
  imageUrls: string[],
  hasReview: boolean,
  createdAt: timestamp,
  acceptedAt?: timestamp,
  completedAt?: timestamp,
  updatedAt: timestamp
}
```

#### 4. Reviews Collection
```javascript
reviews/{reviewId}
{
  jobId: string,
  workerId: string,
  customerId: string,
  rating: number, // 1-5
  comment: string,
  createdAt: timestamp,
  updatedAt: timestamp
}
```

## 🔐 Firebase Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function getUserRole() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role;
    }
    
    function isOwner(userId) {
      return request.auth.uid == userId;
    }
    
    function isAdmin() {
      return isAuthenticated() && getUserRole() == 'admin';
    }

    // Users collection
    match /users/{userId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated() && isOwner(userId);
      allow update: if isAuthenticated() && (isOwner(userId) || isAdmin());
      allow delete: if isAdmin();
    }

    // Reviews collection
    match /reviews/{reviewId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated() && 
                       request.resource.data.customerId == request.auth.uid &&
                       exists(/databases/$(database)/documents/jobs/$(request.resource.data.jobId)) &&
                       get(/databases/$(database)/documents/jobs/$(request.resource.data.jobId)).data.status == 'completed';
      allow update: if isAuthenticated() && 
                       (resource.data.customerId == request.auth.uid || isAdmin());
      allow delete: if isAdmin();
    }
  }
}
```

## ☁️ Cloud Functions

### 1. Update Worker Rating Function
```typescript
export const updateWorkerRating = functions.firestore
  .document("reviews/{reviewId}")
  .onCreate(async (snap, context) => {
    const review = snap.data();
    const workerId = review.workerId;

    // Get all reviews for this worker
    const reviewsSnapshot = await db
      .collection("reviews")
      .where("workerId", "==", workerId)
      .get();

    // Calculate new average rating
    let totalRating = 0;
    let totalReviews = 0;

    reviewsSnapshot.forEach((doc) => {
      const reviewData = doc.data();
      totalRating += reviewData.rating;
      totalReviews++;
    });

    const newAvgRating = totalRating / totalReviews;

    // Update worker document
    await db.collection("workers").doc(workerId).update({
      avgRating: parseFloat(newAvgRating.toFixed(2)),
      ratingCount: totalReviews,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
```

## 🚀 Deployment Steps

### 1. Firebase Project Setup
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase project
firebase init

# Select:
# - Firestore
# - Functions
# - Storage
# - Authentication
```

### 2. Flutter Configuration
```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase for Flutter
flutterfire configure
```

### 3. Android Configuration
Add to `android/app/build.gradle`:
```gradle
android {
    compileSdkVersion 34
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34
    }
}

dependencies {
    implementation 'com.google.firebase:firebase-analytics'
    implementation 'com.google.android.gms:play-services-maps:18.2.0'
}
```

### 4. iOS Configuration
Add to `ios/Runner/Info.plist`:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location access to find nearby workers.</string>
```

### 5. Deploy Cloud Functions
```bash
cd functions
npm install
npm run build
firebase deploy --only functions
```

### 6. Deploy Firestore Rules
```bash
firebase deploy --only firestore:rules
```

### 7. Build and Release
```bash
# Android
flutter build apk --release
# or
flutter build appbundle --release

# iOS
flutter build ios --release
```

## 📱 Key Features Implemented

### ✅ Completed Features
1. **Architecture Setup** - Clean architecture with feature-first approach
2. **Data Models** - User, Worker, Job, and Review models
3. **Authentication** - Firebase Auth with email/password
4. **Review System** - Complete rating and review functionality
5. **Repository Pattern** - Data access layer abstraction
6. **UI Components** - Star rating widgets and review displays
7. **Cloud Functions** - Automatic rating calculations
8. **Security Rules** - Comprehensive Firestore security

### 🔄 Next Steps to Complete
1. **Job Management** - Create, accept, and track jobs
2. **Google Maps Integration** - Location services and mapping
3. **Worker Dashboard** - Profile management and job queue
4. **Push Notifications** - Real-time job updates
5. **Image Upload** - Profile pictures and job images
6. **Chat System** - In-app messaging
7. **Payment Integration** - Optional payment processing
8. **Admin Panel** - Worker verification and monitoring

## 📝 Usage Examples

### Submit a Review
```dart
// Navigate to review screen
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => SubmitReviewScreen(
      job: completedJob,
      worker: workerModel,
    ),
  ),
);
```

### Display Worker Rating
```dart
RatingDisplay(
  rating: worker.avgRating,
  reviewCount: worker.ratingCount,
  starSize: 20,
)
```

### Star Rating Input
```dart
RatingInput(
  title: 'Rate your experience',
  onRatingChanged: (rating) {
    setState(() {
      selectedRating = rating;
    });
  },
)
```

This architecture provides a solid foundation for a production-ready work-connect application with scalable features and clean code organization.