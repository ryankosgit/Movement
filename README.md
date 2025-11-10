<img src="https://github.com/ryankosgit/Movement/blob/master/swift/ryansmega4/icon.png=width=48" width="150" height="150">

# MOVEMENT
Movement is iOS app built by Ryan & Ryan at the AI ATL 2025 Hackathon at Georgia Tech for the [Matt Steele challenge](https://chief-trowel-a22.notion.site/AI-ATL-2025-Hacker-Guide-2671bd5ee852805fb160de97b49c712d#2a41bd5ee85280a9a53dc097e077b954) . The application leverages real-time motion tracking from your iPhone and AirPods to monitor and identify your movements in order to help you acheive your set fitness goals. 

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
│   │   │   ├── train.py                                     #unused notebook for testing
│   ├── ├── notebooks/
│   │   │   ├── .ipynb_checkpoints/
│   │   │   │   ├── 01_visualize_data-checkpoint.ipynb       # Visualized Data
│   │   │   │   ├── 04_create_coreML-checkpoint.ipynb        # Convert Scikit learn to Swift's CoreML
│   │   │   │   ├── compare_data-checkpoint.ipynb            # Compare Movement Data
│   │   │   │   ├── train_basic_model-checkpoint.ipynb       # Train Model
│   │   │   ├── 01_visualize_data.ipynb
│   │   │   ├── 02_compare_data.ipynb
│   │   │   ├── 03_train_basic_model.ipynb
│   │   │   ├── 04_create_coreML.ipynb
│   │   │   ├── ExerciseClassifier.mlmodel
│   │   │   ├── ExerciseClassifier_Windowed.mlmodel
│   │   │   ├── exercise_rf.pkl
│   │   │   ├── exercise_rf_windowed.pkl
├── Swift/
│   │   ├── ryansmega3/ # Motion Tracking Demo
│   │   ├── ryansmega4/ # Final Swift/iOS Project of Submitted Version
│   │   ├── ryansmega4_demo1/ # Archived Working Version
├── .gitignore/
├── README.md/
```
