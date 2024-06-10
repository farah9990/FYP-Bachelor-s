//
//  ContentView.swift
//  ABAN AI
//
//
//

import SwiftUI
import UniformTypeIdentifiers
import AVFoundation


struct ContentView: View {
    @State private var isShowingPicker = false
    @State private var selectdFileURL : URL?
    @State private var audioFileName : String = ""
    @State private var serverResponse: String = ""
    @State private var progress : CGFloat = 0.0
    @State private var AudioFileName :String = ""
    @State private var isLoding: Bool = false
    @State private var showAlretChooseAudio : Bool = false
    @State private var isRecording = false
    @State private var audioRecording = false
    @State private var audioRecorder: AVAudioRecorder?
    @State private var timer: Timer?
    @State private var serverResponseReal: String = ""
    let serverURLforReal = URL(string: "http://192.168.100.9:5000/predict")!
    var body: some View {
        VStack {
            //title of the app
            Text("ABAN AI detection ")
                .font(.title)
                .padding(.top , -80 )
            // Circuler bar to show the percent of the Fakeness in the sound
            CirculerProgressBar(progress: progress)
                .frame(width: 230 , height: 230)
                .padding(.bottom , 10)
            
            if isLoding{
                Text("waiting...")
                    .font(.headline)
                    .padding(.bottom , 10)
            }
            
            //button for send audio to server and update the progress bar
            Button("check"){
                if let fileURL = selectdFileURL {
                    isLoding = true //start loading indicator, and show the user he must wait for precent
                    uploadFileToServer(filePath: fileURL , fileName: AudioFileName ){ success , response in
                        if success{
                            print("Audio uploaded successfully")
                            audioFileName = ""
                            checkMessage()
                            serverResponse = response ?? ""
                        }else {
                            print("Failed to upload audio")
                        }
                    }
                }else{
                    showAlretChooseAudio = true //show alert if audio file not selected
                }
            }
            .padding()
            .font(.headline)
            .background(.mint)
            .foregroundColor(.white)
            .cornerRadius(70)
            .padding(.bottom , 10)
            .disabled(isLoding) // disabled button during loading and waiting
            .alert(isPresented: $showAlretChooseAudio){
                Alert(title: Text("Choose Audio"), message: Text("Please sellect an audio file") ,dismissButton: .default(Text("ok")))
            }
            
            HStack{
                ZStack(alignment: .trailing){
                    //text field to show the name of the audio
                    TextField("Uploaded Audio", text: $AudioFileName)
                        .padding(.vertical , 10 )
                        .padding(.horizontal , 20)
                        .background(Color.lightGray)
                        .cornerRadius(50)
                        .foregroundColor(Color.DarkGray)
                    //button to choose the audio to upload to the app
                    Button("Up"){
                        isShowingPicker = true
                        progress = 0.0
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.vertical , 15)
                    .padding(.horizontal)
                    .background(.mint)
                    .cornerRadius(70)
                    .sheet(isPresented: $isShowingPicker){
                        AudioPicker { url in
                            selectdFileURL = url
                            AudioFileName = url.lastPathComponent
                            
                        }
                    }
                    
                }
                
            }
            VStack{
                //toggle to activate the real-time
                Toggle("Real-Time Dtection", isOn: $isRecording)
                    .padding()
                    .tint(.mint)
                    .background(Color.lightGray)
                    .cornerRadius(100)
                    .foregroundColor(Color.DarkGray)
                    .fontWeight(.medium)
                    .onChange(of: isRecording){newValue in
                        if newValue {
                            checkMicrophonePermission()
                        } else {
                            stopRecording()
                        }
                    }
                    .onAppear {
                        requestPermissions()
                    }
                if isRecording{
                    Text("\(serverResponseReal)")
                        .padding(.bottom, -80 )
                        .shadow(radius: 1)
                    
                }
            }
            
        }
        .padding()
    }
    func checkMessage() {
        guard let url = URL(string: "http://192.168.100.9:5000/check") else {
            print("Invalid URL ")
            return
        }
        let task = URLSession.shared.dataTask(with: url){ data, response , error in
            guard let data = data , error == nil else {
                print("Error: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            if let httpResponse = response as? HTTPURLResponse , httpResponse.statusCode == 200{
                if let responseString = String(data: data , encoding: .utf8 ) , let number = Double(responseString){
                    isLoding = false //stop loading indicator
                    DispatchQueue.main.async {
                        let number = number/100
                        self.progress = number
                    }
                }
            }else {
                print("Failed to recive message")
            }
        }
        task.resume()
    }
    func requestPermissions() {
        checkMicrophonePermission()
    }
    func checkMicrophonePermission() {
        let audioSession = AVAudioSession.sharedInstance()
        switch audioSession.recordPermission {
        case .granted:
            print("Microphone permission granted")
            if isRecording{
                startRecording()
            }
        case .denied:
            print("Microphone permission denied")
        case .undetermined:
            print("Microphone permission undetermined")
            requestMicrophonePermission()
        @unknown default:
            print("Unknown microphone permission status")
        }
    }
    func requestMicrophonePermission() {
        let audioSession = AVAudioSession.sharedInstance()
        audioSession.requestRecordPermission { granted in
            if granted {
                print("Microphone permission granted after request")
                startRecording()
            } else {
                print("Microphone permission denied after request")
            }
        }
    }
    func startRecording() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)

            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsFloatKey: false
            ]

            let audioFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("sound.wav")

            let audioRecorder = try AVAudioRecorder(url: audioFileURL, settings: audioSettings)
            audioRecorder.record()
            self.audioRecorder = audioRecorder

            self.timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { timer in
                self.uploadAudioFile(at: audioFileURL)
            }
        } catch let error {
            print("Error setting up audio recording: \(error)")
        }
    }
    func stopRecording() {
        if let audioRecorder = self.audioRecorder {
            audioRecorder.stop()
            self.audioRecorder = nil
        }
        self.timer?.invalidate()
    }
    func uploadAudioFile(at fileURL: URL) {
        guard let audioRecorder = self.audioRecorder else {
            return
        }

        audioRecorder.stop() // Stop recording before uploading

        uploadFileToServerReal(filePath: fileURL, fileName: "sound.wav", serverURL: serverURLforReal) { success, responseData in
            if success {
                if let data = responseData, let httpResponse = responseData as? HTTPURLResponse {
                    print("Server response status code: \(httpResponse.statusCode)")

                    if (200..<300).contains(httpResponse.statusCode), let responseString = String(data: data, encoding: .utf8) {
                        DispatchQueue.main.async {
                            self.serverResponse = responseString // Update server response state
                        }
                    } else {
                        print("Error: Server did not accept the audio file.")
                    }
                } else {
                    print("Error: Invalid server response.")
                }
            } else {
                print("Error: Failed to upload audio file.")
            }
        }
    }
    func uploadFileToServerReal(filePath: URL, fileName: String, serverURL: URL, completion: @escaping (Bool, Data?) -> Void) {
        var request = URLRequest(url: serverURL)
        request.httpMethod = "POST"
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/mpeg\r\n\r\n".data(using: .utf8)!)

        do {
            let fileData = try Data(contentsOf: filePath)
            body.append(fileData)
            body.append("\r\n".data(using: .utf8)!)
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)

            request.httpBody = body
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Error uploading file: \(error)")
                    completion(false, nil)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("Server response status code: \(httpResponse.statusCode)")
                    
                    if (200..<300).contains(httpResponse.statusCode) {
                        print("File uploaded successfully.")
                        completion(true, data)
                        // Update the serverResponse variable with the response
                        if let data = data {
                            let responseString = String(data: data, encoding: .utf8) ?? ""
                            DispatchQueue.main.async {
                                self.serverResponseReal = responseString
                            }
                        }
                    } else {
                        print("Server returned error: \(httpResponse.statusCode)")
                    }
                }
            }.resume()
        } catch {
            print("Error reading file data: \(error)")
            completion(false, nil)
        }
    }
}

struct AudioPicker: UIViewControllerRepresentable {
    var onAudioSelected : (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.audio] , asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(onAudioSelected : onAudioSelected)
    }
    
    class Coordinator : NSObject , UIDocumentPickerDelegate {
        let onAudioSelected : (URL) -> Void
        init ( onAudioSelected : @escaping (URL)-> Void){
            self.onAudioSelected =  onAudioSelected
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first{
                onAudioSelected(url)
            }
        }
    }
    
}

func uploadFileToServer(filePath: URL, fileName: String, completion: @escaping (Bool, String?) -> Void) {
    guard let fileData = try? Data(contentsOf: filePath) else {
        print("Failed to read file data.")
        completion(false, nil)
        return
    }
    
    let url = URL(string: "http://192.168.100.9:5000/upload-audio")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    
    let boundary = "Boundary-\(UUID().uuidString)"
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    
    var body = Data()
    body.append("--\(boundary)\r\n".data(using: .utf8)!) // Convert string to data
    body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!) // Convert string to data
    body.append("Content-Type: audio/mpeg\r\n\r\n".data(using: .utf8)!) // Convert string to data
    body.append(fileData) // Append binary data directly
    body.append("\r\n".data(using: .utf8)!) // Convert string to data
    body.append("--\(boundary)--\r\n".data(using: .utf8)!) // Convert string to data
    
    request.httpBody = body
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            print("Error uploading file: \(error)")
            completion(false, nil)
            return
        }
        
        if let httpResponse = response as? HTTPURLResponse {
            if (200..<300).contains(httpResponse.statusCode) {
                print("File uploaded successfully.")
                if let responseData = data, let responseString = String(data: responseData, encoding: .utf8) {
                    completion(true, responseString)
                } else {
                    completion(true, nil)
                }
            } else {
                print("Server returned error: \(httpResponse.statusCode)")
                completion(false, nil)
            }
        }
    }.resume()
}