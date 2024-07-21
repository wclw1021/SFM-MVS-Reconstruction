import os
import cv2

def extract_images(video_path, output_folder):
    # Get the video file name
    video_name = os.path.splitext(os.path.basename(video_path))[0]
    # Create a new folder
    output_path = os.path.join(output_folder, video_name)
    if not os.path.exists(output_path):
        os.makedirs(output_path)
    # Open the video
    cap = cv2.VideoCapture(video_path)
    # Set frame interval
    frame_interval = int(16)
    # Extract and save frames that meet the interval requirement
    count = 0
    while cap.isOpened():
        ret, frame = cap.read()
        if ret:
            print(frame_interval)
            if count % frame_interval == 0:
                image_name = os.path.join(output_path, f"{video_name}_{count//frame_interval}.jpg")
                cv2.imwrite(image_name, frame)
            count += 1
        else:
            break
    cap.release()

if __name__ == '__main__':
    video_path = 'D:/preprocessing/12.mp4'  # Path to the video file
    output_folder = 'D:/preprocessing'  # Path to the output folder
    extract_images(video_path, output_folder)

