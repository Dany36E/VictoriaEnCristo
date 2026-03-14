# ProGuard rules for the Faith Victory App

# Keep the application class
-keep class com.faithvictory.FaithVictoryApp { *; }

# Keep all activities
-keep class com.faithvictory.**Activity { *; }

# Keep all fragments
-keep class com.faithvictory.**Fragment { *; }

# Keep all ViewModels
-keep class com.faithvictory.**ViewModel { *; }

# Keep all data classes
-keep class com.faithvictory.data.** { *; }

# Keep all entities
-keep class com.faithvictory.data.local.entities.** { *; }

# Keep all DAOs
-keep class com.faithvictory.data.local.dao.** { *; }

# Keep all repositories
-keep class com.faithvictory.data.repository.** { *; }

# Keep all UI components
-keep class com.faithvictory.ui.components.** { *; }

# Keep all navigation components
-keep class com.faithvictory.ui.navigation.** { *; }

# Keep all utils
-keep class com.faithvictory.utils.** { *; }

# Keep all theme resources
-keep class com.faithvictory.ui.theme.** { *; }

# Keep all strings resources
-keep class **.R$strings { *; }
-keep class **.R$color { *; }
-keep class **.R$drawable { *; }
-keep class **.R$layout { *; }
-keep class **.R$menu { *; }
-keep class **.R$values { *; }

# Keep Gson models
-keep class com.faithvictory.data.local.entities.** {
    <fields>;
}

# Keep Retrofit models
-keep class com.faithvictory.data.repository.** {
    <fields>;
}

# Keep Parcelable classes
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}