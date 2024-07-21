This project primarily implements the classic Structure-from-Motion and Multi-View Stereo (SFM-MVS) approach for 3D reconstruction. It is based on modifications made to the SFMedu: Structure From Motion for Education Purpose, Version 2 @ 2014 framework, which was originally written by Jianxiong Xiao and is available under the MIT License. The project provides a comprehensive walkthrough of the entire method, incorporating improvements to enhance the original approach. Additionally, it integrates other relevant articles related to 3D reconstruction and compares various methods to evaluate their effectiveness and performance.

To run the MATLAB scripts in SFM_MVS, you need MATLAB version R2022b or later. This is because earlier versions may not have access to the Poisson reconstruction functions, which are essential for the mesh reconstruction feature. Additionally, the Statistics and Machine Learning Toolbox is required, as the scripts utilize sampling functions from this toolbox. Without this toolbox, the program may not function correctly.

To execute the video frame extraction Python script in dataprocessing, you need to have OpenCV installed and properly configured.

The Outcomes folder contains the results obtained from the experiments.

The data folder contains the data necessary for the experiments.


