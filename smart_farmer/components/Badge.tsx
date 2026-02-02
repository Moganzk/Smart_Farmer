/**
 * Badge - Notification badge component
 * 
 * Displays a small badge with a count. Hides when count is 0.
 * Used for unread notifications, messages, etc.
 */

import React from 'react';
import { View, Text, StyleSheet } from 'react-native';

interface BadgeProps {
  /** Number to display in the badge */
  count: number;
  /** Maximum count to display (default: 99, shows "99+" if exceeded) */
  max?: number;
  /** Badge background color (default: red) */
  color?: string;
  /** Text color (default: white) */
  textColor?: string;
  /** Size variant (default: 'small') */
  size?: 'small' | 'medium';
}

export function Badge({
  count,
  max = 99,
  color = '#F44336',
  textColor = '#FFFFFF',
  size = 'small',
}: BadgeProps) {
  if (count <= 0) {
    return null;
  }

  const displayText = count > max ? `${max}+` : String(count);
  const sizeStyles = size === 'medium' ? styles.medium : styles.small;
  const textSizeStyles = size === 'medium' ? styles.textMedium : styles.textSmall;

  return (
    <View style={[styles.badge, sizeStyles, { backgroundColor: color }]}>
      <Text style={[styles.text, textSizeStyles, { color: textColor }]}>
        {displayText}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  badge: {
    position: 'absolute',
    top: -4,
    right: -4,
    borderRadius: 10,
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 1.5,
    borderColor: '#FFFFFF',
  },
  small: {
    minWidth: 16,
    height: 16,
    paddingHorizontal: 4,
  },
  medium: {
    minWidth: 20,
    height: 20,
    paddingHorizontal: 5,
  },
  text: {
    fontWeight: 'bold',
  },
  textSmall: {
    fontSize: 10,
  },
  textMedium: {
    fontSize: 12,
  },
});

export default Badge;
