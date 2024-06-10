import numpy as np 
import librosa 
import pickle 
import librosa
import os


# upload the model 
with open('xgboost_model.pkl', 'rb') as f:
    xgboost_model = pickle.load(f)


# function to extract feauters of the audio, same as what the model dataset\
def extract_audio_features(segment, sr):
    chroma_stft = np.mean(librosa.feature.chroma_stft(y=segment, sr=sr))
    rms = np.mean(librosa.feature.rms(y=segment))
    spectral_centroid = np.mean(librosa.feature.spectral_centroid(y=segment, sr=sr)[0])
    spectral_bandwidth = np.mean(librosa.feature.spectral_bandwidth(y=segment, sr=sr)[0])
    rolloff = np.mean(librosa.feature.spectral_rolloff(y=segment, sr=sr)[0])
    zero_crossing_rate = np.mean(librosa.feature.zero_crossing_rate(y=segment)[0])
    mfccs = librosa.feature.mfcc(y=segment, sr=sr, n_mfcc=20)

    features = {
        'chroma_stft': chroma_stft,
        'rms': rms,
        'spectral_centroid': spectral_centroid,
        'spectral_bandwidth': spectral_bandwidth,
        'rolloff': rolloff,
        'zero_crossing_rate': zero_crossing_rate
    }

    for i in range(1, 21):
        features[f'mfcc{i}'] = np.mean(mfccs[i-1])
    return features

## calculte the percent
def real_time_percent():
    audio = 'real_time_audio.wav'  # Path to the audio file
    x, sr = librosa.load( audio)
    audio_features = extract_audio_features(x, sr)
    feature_values = list(audio_features.values())
    audio_features_array = np.array(feature_values).reshape(1, -1)
    prediction = xgboost_model.predict(audio_features_array)
    
    if prediction[0] == 1:
        result = "true"
    elif prediction[0] == 0:
        result = "false"

    # Delete the audio file after getting the prediction
    try:
        os.remove(audio)
        print("Audio file deleted successfully.")
    except OSError as e:
        print("Error deleting audio file:", e)

    return result