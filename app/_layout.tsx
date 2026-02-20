import { useEffect } from 'react';
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { useFonts } from 'expo-font';
import * as SplashScreen from 'expo-splash-screen';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { QueryProvider } from '@/providers/QueryProvider';

// Inter font variants
import {
  Inter_300Light,
  Inter_400Regular,
  Inter_500Medium,
  Inter_600SemiBold,
  Inter_700Bold,
} from '@expo-google-fonts/inter';

// Lora font variants
import {
  Lora_400Regular,
  Lora_500Medium,
  Lora_600SemiBold,
  Lora_700Bold,
} from '@expo-google-fonts/lora';

// Playfair Display font variants
import {
  PlayfairDisplay_400Regular,
  PlayfairDisplay_500Medium,
  PlayfairDisplay_600SemiBold,
  PlayfairDisplay_700Bold,
} from '@expo-google-fonts/playfair-display';

// JetBrains Mono font variants
import {
  JetBrainsMono_300Light,
  JetBrainsMono_400Regular,
  JetBrainsMono_500Medium,
  JetBrainsMono_600SemiBold,
  JetBrainsMono_700Bold,
} from '@expo-google-fonts/jetbrains-mono';

// Gaegu font variants
import {
  Gaegu_300Light,
  Gaegu_400Regular,
  Gaegu_700Bold,
} from '@expo-google-fonts/gaegu';

SplashScreen.preventAutoHideAsync();

export default function RootLayout() {
  const [fontsLoaded] = useFonts({
    // Legacy fonts (keeping for backward compatibility)
    Inter: require('../assets/fonts/Inter.ttf'),
    Lora: require('../assets/fonts/Lora.ttf'),
    PlayfairDisplay: require('../assets/fonts/PlayfairDisplay.ttf'),
    
    // Text overlay font variants (weight-specific)
    Inter_300Light,
    Inter_400Regular,
    Inter_500Medium,
    Inter_600SemiBold,
    Inter_700Bold,
    Lora_400Regular,
    Lora_500Medium,
    Lora_600SemiBold,
    Lora_700Bold,
    PlayfairDisplay_400Regular,
    PlayfairDisplay_500Medium,
    PlayfairDisplay_600SemiBold,
    PlayfairDisplay_700Bold,
    JetBrainsMono_300Light,
    JetBrainsMono_400Regular,
    JetBrainsMono_500Medium,
    JetBrainsMono_600SemiBold,
    JetBrainsMono_700Bold,
    Gaegu_300Light,
    Gaegu_400Regular,
    Gaegu_700Bold,
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
