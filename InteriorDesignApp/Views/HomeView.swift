import SwiftUI

struct HomeView: View {
    @State private var navigateToCaptureView = false
    var switchToLibraryTab: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()
                
                // App logo/icon
                Image(systemName: "house.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .foregroundColor(.blue)
                
                // App title
                Text("Interior Design AI")
                    .font(.system(size: 32, weight: .bold))
                
                Text("Transform empty rooms with AI-powered interior design")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                
                // Create new design button
                Button(action: {
                    print("DEBUG: Create New Design button tapped")
                    navigateToCaptureView = true
                }) {
                    HStack {
                        Image(systemName: "wand.and.stars")
                        Text("Create New Design")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                NavigationLink(
                    destination: CaptureView(switchToLibraryTab: switchToLibraryTab),
                    isActive: $navigateToCaptureView,
                    label: { EmptyView() }
                )
                .onChange(of: navigateToCaptureView) { isActive in
                    print("DEBUG: HomeView NavigationLink isActive changed to: \(isActive)")
                }
            }
            .padding()
            .navigationBarHidden(true)
            .onAppear {
                print("DEBUG: HomeView appeared")
                // Reset navigation state when returning to this tab
                if navigateToCaptureView {
                    print("DEBUG: Resetting navigateToCaptureView from true to false")
                    navigateToCaptureView = false
                }
            }
            .onDisappear {
                print("DEBUG: HomeView disappeared")
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

#if DEBUG
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(switchToLibraryTab: {})
    }
}
#endif 