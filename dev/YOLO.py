from ultralytics import YOLO

# Load the pre-trained YOLOv10-N model
# model = YOLO("yolov10n.pt")
model = YOLO("yolov8n-pose.pt")  # load an official model
results = model("video.MOV")
results[0].show()
