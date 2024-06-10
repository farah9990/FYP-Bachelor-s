
import numpy as np
import tensorflow as tf 
import librosa 
import pandas as pd 
import tensorflow_io as tfio
import soundfile as sf 
import subprocess
import tqdm
import os
import pickle 
from scipy.io.wavfile import write 
from pydub import AudioSegment


AudioFromUser = r"C:\Users\shaha\OneDrive\Desktop\FYP\Graduation_Project\audio.wav"
folder_path = r"C:\Users\shaha\OneDrive\Desktop\FYP\Graduation_Project\audio_slice"

#loading the model 
with open('trained_model.pkl', 'rb') as file:
    CNN_LSTM = pickle.load(file)
    
    
##functions to clean the audio 
def calculate_threshold(audio , factor =2 ):
    RootMeanSquare = np.sqrt(np.mean(np.square(audio)))
    threshold =RootMeanSquare * factor
    return threshold

def remove_noise(audio, sampleRate, threshold):
    audio_abs = np.abs(audio)
    window_size = int (sampleRate / 20)
    audio_mean = pd.Series(audio_abs).rolling(window = window_size , min_periods = 1 , center = True).max()
    mask = audio_mean > threshold
    no_noise_audio = np.where(mask , audio , 0 )
    return no_noise_audio 

def find_silence(audio_path , time ):
    ffmpeg_path = 'C:/Path_program/ffmpeg.exe'
    command = f"{ffmpeg_path} -i {audio_path}  -af silencedetect=n=-23dB:d={time} -f null -"
    out = subprocess.Popen(command , stdout =subprocess.PIPE , stderr = subprocess.STDOUT)
    stdout , stderr = out.communicate()
    s = stdout.decode("utf-8")
    k=s.split('[silencedetect @')
    
    if len (k) == 1:
        return None
    
    start , end = [] , [] 
    for i in range(1 , len(k)):
        x = k[i].split(']')[1]
        if i % 2 == 0 :
            x = x.split('|')[0]
            x = x.split(':')[1].strip()
            end.append(float(x))
        else :
            x = x.split(':')[1]
            x = x.split('size')[0]
            x = x.replace('\r' , '')
            x = x.replace('\n', '').strip()
            start.append(float(x))
            
    return list(zip(start , end))
    
def remove_silence(audio , silence_parts , sampleRate , out_path):
    silence_parts_updated = [(i[0] , i[1]) for i in silence_parts ]
    
    non_silence = []
    temp = 0 
    ed = len(audio) /sampleRate 
    
    for start , end in silence_parts_updated :
        non_silence.append((temp , start))
        temp = end
    if silence_parts_updated[-1][1] < ed :
        non_silence.append((silence_parts_updated[-1][1], ed))
    if non_silence[0][0] == non_silence[0][1]:
        del non_silence[0]
    
    print('Slicing started...')
    ans = []
    for start , end in tqdm.tqdm(non_silence):
        ans.append(audio[int(start* sampleRate) : int(end*sampleRate)])
    ans = np.concatenate(ans)
    write(out_path , sampleRate ,ans)
    return non_silence

def preprocessing_Audio():
    audio , sampleRate = librosa.load(AudioFromUser)
    threshold_for_audio = calculate_threshold(audio , factor =2)
    NoNoise_audio = remove_noise(audio, sampleRate, threshold_for_audio)
    sf.write(AudioFromUser , NoNoise_audio , sampleRate)
    denoised_audio , sample_rate = librosa.load(AudioFromUser)
    silence_parts = find_silence(AudioFromUser , 1.5)
    if silence_parts :
        remove_silence(denoised_audio , silence_parts ,sample_rate ,AudioFromUser)

##function to cut audio in samll parts 

def slice_audio(audio_path , segment_duration_ms=3000 , output_folder = "audio_slice"):
    if not os.path.exists(output_folder):
        os.makedirs(output_folder)
        
    audio = AudioSegment.from_file(audio_path)
    total_duration_ms= len(audio)
    number_of_segments = total_duration_ms // segment_duration_ms 
    if total_duration_ms % segment_duration_ms !=0 :
        number_of_segments +=1
        
    for i in range(number_of_segments):
        start_time = i * segment_duration_ms 
        end_time = min(start_time + segment_duration_ms, len(audio))  
        segment = audio[start_time : end_time]
        
        segment = segment.set_sample_width(2)
        segment.export(os.path.join(output_folder , f"segment_{i}.wav"), format="wav")
             
##loading function and preprocessing the audio used in dataset for the model 
def load_function(filename):
  fiel_content= tf.io.read_file(filename)
  wav , sample_rate = tf.audio.decode_wav(fiel_content , desired_channels=1)
  wav = tf.squeeze(wav , axis= -1)
  sample_rate = tf.cast(sample_rate , dtype= tf.int64)
  wav = tfio.audio.resample(wav , rate_in=sample_rate , rate_out=1600)
  return wav

def preprocess_audio(file_path):
    wav = load_function(file_path)
    wav = wav[:6000]
    zero_padding = tf.zeros([6000] - tf.shape(wav), dtype=tf.float32)
    wav = tf.concat([zero_padding, wav], 0)
    spectrogram = tf.signal.stft(wav, frame_length=320, frame_step=32)
    spectrogram = tf.abs(spectrogram)
    spectrogram = tf.expand_dims(spectrogram, axis=2)
    return spectrogram

## predict the fakeness in the audio 
def predict_audio():
    print("audio noe prpcess to get prdict")
    audio_files = [os.path.join(folder_path, f) for f in os.listdir(folder_path) if f.endswith('.wav')]
    all_predictions = []
    for file_path in audio_files:
        preprocessed_audio = preprocess_audio(file_path) 
        reshaped_input = np.reshape(preprocessed_audio, (-1, 178, 257, 1))
        predictions = CNN_LSTM.predict(reshaped_input)
        prediction_labels = [1 if round(float(prediction), 1) > 0.9 else 0 for prediction in predictions]
        all_predictions.append(prediction_labels)
        os.remove(file_path)
        
    print("got the prediction")
    all_predictions = np.array(all_predictions)
    return all_predictions
    
## get the perecent of fakeness 
    
def calculte_percent(all_predictions):
    print("got the percentage")
    total_predictions = all_predictions.size
    values, counts = np.unique(all_predictions, return_counts=True)
    percentages = counts / total_predictions * 100
    percent_1 = 0
    for value, percentage in zip(values, percentages):
        if value == 1:
            percent_1 = percentage
    print("got the percentage")
    return  percent_1

 
## function call in the server  
def get_percent():
    preprocessing_Audio()
    slice_audio(AudioFromUser , segment_duration_ms=3000 , output_folder = "audio_slice")
    predictions  = predict_audio()
    percent = calculte_percent(predictions)
    os.remove(AudioFromUser)
    return str(percent)
        
