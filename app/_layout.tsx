import { useEffect } from 'react';
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { useFonts } from 'expo-font';
import * as SplashScreen from 'expo-splash-screen';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { QueryProvider } from '@/providers/QueryProvider';

SplashScreen.preventAutoHideAsync();

export default function RootLayout() {
  const [fontsLoaded] = useFonts({
    Inter: require('../assets/fonts/Inter.ttf'),
    Lora: require('../assets/fonts/Lora.ttf'),
    PlayfairDisplay: require('../assets/fonts/PlayfairDisplay.ttf'),
  });

  useEffect(() => {
    if (fontsLoaded) {
      SplashScreen.hideAsync();
    }
  }, [fontsLoaded]);

  if (!fontsLoaded) return null;

  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <QueryProvider>
          <Stack screenOptions={{ headerShown: false }}>
            <Stack.Screen name="index" />
            <Stack.Screen name="(tabs)" />
            <Stack.Screen
              name="reader/[id]"
              options={{ animation: 'slide_from_bottom', gestureEnabled: false }}
            />
          </Stack>
          <StatusBar style="auto" />
      </QueryProvider>
    </GestureHandlerRootView>
  );
}
