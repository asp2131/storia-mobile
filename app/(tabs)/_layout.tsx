import { Tabs } from 'expo-router';
import { useThemeColors } from '@/lib/theme';

export default function TabLayout() {
  const colors = useThemeColors();

  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: colors.storiaPrimary,
        tabBarInactiveTintColor: colors.textSecondary,
        tabBarStyle: {
          backgroundColor: colors.storiaNavBg,
          borderTopColor: colors.storiaBorder,
        },
        tabBarLabelStyle: {
          fontSize: 12,
          fontWeight: '600',
        },
      }}
    >
      <Tabs.Screen
        name="library"
        options={{
          title: 'Library',
          tabBarIcon: ({ color, size }) => (
            <TabIcon name="library" color={color} size={size} />
          ),
        }}
      />
      <Tabs.Screen
        name="downloads"
        options={{
          title: 'Downloads',
          tabBarIcon: ({ color, size }) => (
            <TabIcon name="downloads" color={color} size={size} />
          ),
        }}
      />
    </Tabs>
  );
}

// Simple text-based icons (replace with proper icon library later)
function TabIcon({ name, color, size }: { name: string; color: string; size: number }) {
  const icons: Record<string, string> = {
    library: '\u{1F4DA}',
    downloads: '\u{2B07}',
  };

  const { Text } = require('react-native');
  return <Text style={{ fontSize: size - 4, color }}>{icons[name] || '?'}</Text>;
}
