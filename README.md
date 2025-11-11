<img src="https://github.com/ryankosgit/Movement/blob/master/swift/ryansmega4/icon.png" width="150" height="150">

# MOVEMENT
Movement is iOS app built by Ryan B & Ryan K at the AI ATL 2025 Hackathon at Georgia Tech for the [Matt Steele challenge](https://chief-trowel-a22.notion.site/AI-ATL-2025-Hacker-Guide-2671bd5ee852805fb160de97b49c712d#2a41bd5ee85280a9a53dc097e077b954). It leverages machine learning and iOS development features to help users acheive their workout goals.

## README GUIDE
-  PROJECT STRUCTURE
-  PROJECT SUMMARY
-  DATA & MODEL TRAINING
-  FILE & INFO
-  INSIDE THE APP (Video/Images Included)


# PROJECT STRUCTURE
```text
Movement
├── ML/
│   ├── data/raw/ # Raw movement data we collected to train our model
│   │   │   ├── ryanb_jumping jacks_20reps_1762618810.xlsx   #Ryan B's 20 Recorded Jumping Jacks
│   │   │   ├── ryanb_pushup_20reps_1762618264.xlsx          #Ryan B's 20 Recorded Pushups
│   │   │   ├── ryanb_squat_20reps_1762615894.xlsx           #Ryan B's 20 Recorded Squats
│   │   │   ├── ryank_jumping_jack_20reps_1762615339.xlsx    #Ryan K's 20 Recorded Jumping Jacks
│   │   │   ├── ryank_pushup_20reps_1762612126.xlsx          #Ryan K's 20 Recorded Pushups
│   │   │   ├── ryank_squat_20reps_1762617710.xlsx           #Ryan K's 20 Recorded Squats
│   ├── ├── models/
│   │   │   ├── train.py                                    
│   ├── ├── notebooks/
│   │   │   ├── 01_visualize_data.ipynb                      # Visualized Data
│   │   │   ├── 02_compare_data.ipynb                        # Compare Movement Data
│   │   │   ├── 03_train_basic_model.ipynb                   # Trained SK learn to identify exercise - 98% accurate
│   │   │   ├── 04_create_coreML.ipynb                       # Convert SK learn to Swift CORE ML
│   │   │   ├── ExerciseClassifier.mlmodel                   # Demo 1 of Exercise Classifier
│   │   │   ├── ExerciseClassifier_Windowed.mlmodel          # Final Working Exercise Classifier
│   │   │   ├── exercise_rf.pkl                              # Data Prototype for Swift App
│   │   │   ├── exercise_rf_windowed.pkl                     # Final Working Data for Swift App
├── Swift/
│   │   ├── ryansmega4/ # Final Swift Project Folder
│   │   │   ├── ryansmega4/
│   │   │   │   ├── ContentView.swift                        # Application UI
│   │   │   │   ├── RealtimeExerciseClassifier.swift         # Real Time Exercise/Movement Classifier
│   │   │   │   ├── RoutineManagementView.swift              # Routine Builder View
│   │   │   │   ├── GuidedWorkoutView.swift                  # Guided Workout View
│   │   │   │   ├── ...                                      # Misc. Swift Files
├── .gitignore/
├── README.md/
```

# Project Summary
- Movement tracks your body's live motion from your AirPods and iPhone leveraging Swift's CoreMotion library and haptic feedback to identify and count your exercise reps to assist in you acheive your fitness goals that you set. 
- The three exercise tracks are jumping jacks, squats, and push-ups. You can either use Free Mode, which automatically detects 1 of the 3 exercises integrated in our app, or you can build a routine and follow it using the Guided Workout tools. 

# Data & Model Training
- We created our own data by recording ourselves performing 20 reps of each exercise. Our application tracks iPhone and Airpods' acceleration and rotation, and we experimented using various exercise form and having our phone in both the right/left pockets, and wore different pants for sample diversification.
- Scikit-learn was used to train the model for recognizing user movements, and acheived a 98% accuracy rate. After a warm up, each rep is counted when the phone's angular velocity reach the minimum and maximum thresholds we designed observing our recorded data.

# File and Info
The ```/raw``` folder in ```/data``` contains our real life exercise movements that we used to train the data. 

The ```notebooks/``` folder contains files of our visualized data, our trained Scikit-learn model, SKlearn to CoreML conversion for the Swift app to understand, and a final exercise classifier and data for the Swift app. 

```ryansmega4/``` is the Swift folder that contains the full Swift application. Inside it contains files with the app's UI, movement trackers, and other tools for the application's functionality. 

# Inside the App
### Home Page

<img width="150" height="300" alt="IMG_1270" src="https://github.com/user-attachments/assets/000ccc4d-8fc8-4c11-b3cf-95fd911fe2f0" />

The home page contains the App title and three buttons for Free Mode, Build Workout Routines, and Start Workout Routine.
### Free Mode

<img width="150" height="300" alt="IMG_1274" src="https://github.com/user-attachments/assets/a64776b8-f91e-464e-9d4d-7cbd2367e529" /> 

https://github.com/user-attachments/assets/b95c48ca-71a8-480e-b3ed-e52dc986bf83

Free mode recognizes any exercise your are currently doing (jumping jack, squat, and/or pushup) while tracking your spacial movement metrics and counting your reps for each exercise. 
### Build Workout Routines

<img width="150" height="300" alt="IMG_1277" src="https://github.com/user-attachments/assets/a0d1a0f3-b732-4ea2-a0c7-6ace7a64731f" />

This allows you to design any workout in order for you to complete using the Guided Workout tool.
### Start Guided Workout

https://github.com/user-attachments/assets/fe600392-bdb1-43be-9584-175ad1b0dd5e

Here's where the magic is. Upon selecting which of your workout routines you want to pursue, simply put the phone in your pocket and let your body do the rest. After a short warm up, the app records your reps.

# Thank You
Thank you to Georgia Tech for hosting this hackathon and the opportunity to participate! 
