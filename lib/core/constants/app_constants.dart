class AppConstants {
  // App Info
  static const String appName = 'WorkConnect';
  static const String appVersion = '1.0.0';
  
  // User Roles
  static const String customerRole = 'customer';
  static const String workerRole = 'worker';
  static const String adminRole = 'admin';
  
  // Job Status
  static const String jobStatusRequested = 'requested';
  static const String jobStatusAccepted = 'accepted';
  static const String jobStatusInProgress = 'in_progress';
  static const String jobStatusCompleted = 'completed';
  static const String jobStatusCancelled = 'cancelled';
  
  // Service Categories
  static const List<String> serviceCategories = [
    'Plumber',
    'Electrician',
    'Mechanic',
    'Technician',
    'Carpenter',
    'Painter',
    'Cleaner',
    'Gardener',
    'AC Repair',
    'Appliance Repair',
  ];
  
  // Firebase Collections
  static const String usersCollection = 'users';
  static const String workersCollection = 'workers';
  static const String jobsCollection = 'jobs';
  static const String reviewsCollection = 'reviews';
  static const String chatCollection = 'chats';
  
  // Pagination
  static const int defaultPageSize = 20;
  
  // Search Radius (in kilometers)
  static const double defaultSearchRadius = 10.0;
  
  // Rating Constraints
  static const int minRating = 1;
  static const int maxRating = 5;
}