Make the following changes:

     - Add a new tab, called 'More'
          - There as first option give 'Bus Time'
               And create a page based on code below (for flutter from raect native)
               
```javascript
import React, { useState, useEffect } from 'react';
import { View, Text, ScrollView, TouchableOpacity, StatusBar, SafeAreaView, ImageBackground } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { Ionicons } from '@expo/vector-icons';

// Bus schedule data
const busSchedules = {
  "S.S College": {
    "EDAVANNAPPARA": [
      "06:30 AM", "06:35 AM", "06:40 AM", "06:55 AM", "07:20 AM", "07:40 AM", "07:55 AM",
      "08:10 AM", "08:15 AM", "08:30 AM", "08:40 AM", "08:50 AM", "09:05 AM", "09:25 AM",
      "09:40 AM", "10:05 AM", "10:13 AM", "10:18 AM", "10:40 AM", "10:50 AM", "11:05 AM",
      "11:20 AM", "11:38 AM", "11:55 AM", "12:03 PM", "12:18 PM", "12:30 PM", "12:40 PM",
      "01:08 PM", "01:32 PM", "01:42 PM", "01:50 PM", "01:55 PM", "02:05 PM", "02:15 PM",
      "02:25 PM", "02:48 PM", "03:00 PM", "03:10 PM", "03:25 PM", "03:40 PM", "04:05 PM",
      "04:20 PM", "04:37 PM", "04:50 PM", "04:55 PM", "05:10 PM", "05:22 PM", "05:35 PM",
      "05:45 PM", "05:53 PM", "05:55 PM", "06:03 PM", "06:13 PM", "06:23 PM", "06:35 PM"
    ],
    "AREEKODE": [
      "07:06 AM", "07:28 AM", "07:43 AM", "07:53 AM", "08:03 AM", "08:20 AM", "08:35 AM", 
      "08:50 AM", "09:13 AM", "09:23 AM", "09:35 AM", "09:43 AM", "10:02 AM", "10:20 AM", 
      "10:31 AM", "10:35 AM", "10:53 AM", "11:03 AM", "11:20 AM", "11:30 AM", "11:38 AM", 
      "11:58 AM", "12:18 PM", "12:28 PM", "12:33 PM", "12:43 PM", "12:50 PM", "01:03 PM",
      "01:11 PM", "01:18 PM", "01:31 PM", "01:48 PM", "02:03 PM", "02:16 PM", "02:33 PM", 
      "02:48 PM", "03:10 PM", "03:38 PM", "03:48 PM", "03:58 PM", "04:08 PM", "04:16 PM", 
      "04:33 PM", "04:50 PM", "04:58 PM", "05:10 PM", "05:18 PM", "05:38 PM", "05:43 PM", 
      "06:01 PM", "06:10 PM", "06:18 PM", "06:23 PM", "06:38 PM", "06:48 PM", "07:08 PM"
    ]
  },
  "EDAVANNAPPARA": {
    "S.S College": [
      "08:00 AM", "08:15 AM", "08:35 AM", "08:55 AM", "09:15 AM", "09:30 AM", "09:45 AM",
      "10:05 AM", "10:20 AM", "10:35 AM", "10:50 AM", "11:10 AM", "11:25 AM", "11:40 AM",
      "12:00 PM", "12:15 PM", "12:30 PM", "12:45 PM", "01:00 PM", "01:15 PM", "01:30 PM",
      "01:45 PM", "02:00 PM", "02:15 PM", "02:30 PM", "02:45 PM", "03:00 PM", "03:15 PM",
      "03:30 PM", "03:45 PM", "04:00 PM", "04:15 PM", "04:30 PM", "04:45 PM", "05:00 PM",
      "05:15 PM", "05:30 PM", "05:45 PM", "06:00 PM", "06:15 PM", "06:30 PM"
    ],
    "AREEKODE": [] // Will be filled with calculated times
  },
  "AREEKODE": {
    "S.S College": [],
    "EDAVANNAPPARA": [] // Will be filled with calculated times
  }
};

// Calculate EDAVANNAPPARA to AREEKODE (18 + 2 = 20 minutes travel time)
busSchedules["EDAVANNAPPARA"]["AREEKODE"] = busSchedules["EDAVANNAPPARA"]["S.S College"].map(time => {
  return addMinutesToTime(time, 0);
});

// Calculate AREEKODE to S.S College (direct, approx 2 minutes)
busSchedules["AREEKODE"]["S.S College"] = busSchedules["S.S College"]["EDAVANNAPPARA"].map(time => {
  return addMinutesToTime(time, -2); // Adding 30 min for return journey
});

// Calculate AREEKODE to EDAVANNAPPARA (approx 18 minutes)
busSchedules["AREEKODE"]["EDAVANNAPPARA"] = busSchedules["S.S College"]["EDAVANNAPPARA"].map(time => {
  return addMinutesToTime(time, -2); // Adding 28 min for return journey
});

// Helper function to add minutes to a time string
function addMinutesToTime(timeStr, minutesToAdd) {
  const [time, period] = timeStr.split(' ');
  const [hours, minutes] = time.split(':').map(Number);
  
  let totalMinutes = hours * 60 + minutes;
  totalMinutes += minutesToAdd;
  
  let newHours = Math.floor(totalMinutes / 60);
  let newMinutes = totalMinutes % 60;
  
  let newPeriod = period;
  if (newHours > 12) {
    newHours -= 12;
    if (period === 'AM') newPeriod = 'PM';
  }
  
  if (newHours === 12 && period === 'AM') {
    newPeriod = 'PM';
  }
  
  return `${String(newHours).padStart(2, '0')}:${String(newMinutes).padStart(2, '0')} ${newPeriod}`;
}

// Convert time string to minutes since midnight for comparison
function timeToMinutes(timeStr) {
  const [time, period] = timeStr.split(' ');
  const [hours, minutes] = time.split(':').map(Number);
  
  let totalMinutes = hours * 60 + minutes;
  if (period === 'PM' && hours !== 12) {
    totalMinutes += 12 * 60;
  } else if (period === 'AM' && hours === 12) {
    totalMinutes -= 12 * 60;
  }
  
  return totalMinutes;
}

// Get current time in the format "HH:MM AM/PM"
function getCurrentTime() {
  const now = new Date();
  let hours = now.getHours();
  const minutes = now.getMinutes();
  const period = hours >= 12 ? 'PM' : 'AM';
  
  hours = hours % 12;
  hours = hours ? hours : 12; // Convert 0 to 12
  
  return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')} ${period}`;
}

export default function BusScheduleApp() {
  const [origin, setOrigin] = useState("S.S College");
  const [destination, setDestination] = useState("EDAVANNAPPARA");
  const [currentTime, setCurrentTime] = useState(getCurrentTime());
  const [nextBus, setNextBus] = useState(null);
  
  const locations = ["S.S College", "EDAVANNAPPARA", "AREEKODE"];
  
  useEffect(() => {
    // Update current time every minute
    const timer = setInterval(() => {
      setCurrentTime(getCurrentTime());
    }, 60000);
    
    return () => clearInterval(timer);
  }, []);
  
  useEffect(() => {
    // Find next bus whenever origin/destination/time changes
    findNextBus();
  }, [origin, destination, currentTime]);
  
  const findNextBus = () => {
    if (!busSchedules[origin] || !busSchedules[origin][destination] || busSchedules[origin][destination].length === 0) {
      setNextBus(null);
      return;
    }
    
    const currentMinutes = timeToMinutes(currentTime);
    let closestBus = null;
    let smallestDifference = Infinity;
    
    for (const time of busSchedules[origin][destination]) {
      const busMinutes = timeToMinutes(time);
      const difference = busMinutes - currentMinutes;
      
      if (difference >= 0 && difference < smallestDifference) {
        smallestDifference = difference;
        closestBus = {
          time,
          minutes: difference
        };
      }
    }
    
    // If no bus found for today, get the first bus for tomorrow
    if (!closestBus && busSchedules[origin][destination].length > 0) {
      const firstBusTomorrow = busSchedules[origin][destination][0];
      const tomorrowMinutes = timeToMinutes(firstBusTomorrow) + 24 * 60;
      const difference = tomorrowMinutes - currentMinutes;
      
      closestBus = {
        time: firstBusTomorrow,
        minutes: difference,
        tomorrow: true
      };
    }
    
    setNextBus(closestBus);
  };
  
  const handleOriginChange = (newOrigin) => {
    if (newOrigin === destination) {
      // Swap origin and destination
      setOrigin(newOrigin);
      setDestination(origin);
    } else {
      setOrigin(newOrigin);
    }
  };
  
  const handleDestinationChange = (newDestination) => {
    if (newDestination === origin) {
      // Swap origin and destination
      setDestination(newDestination);
      setOrigin(destination);
    } else {
      setDestination(newDestination);
    }
  };
  
  const formatTimeRemaining = (minutes) => {
    if (minutes < 60) {
      return `${minutes} min`;
    } else {
      const hours = Math.floor(minutes / 60);
      const mins = minutes % 60;
      return `${hours}h ${mins}m`;
    }
  };
  
  const getRouteInfo = () => {
    if (origin === "S.S College" && destination === "EDAVANNAPPARA") {
      return "Direct - 18 min";
    } else if (origin === "S.S College" && destination === "AREEKODE") {
      return "Direct - 2 min";
    } else if (origin === "EDAVANNAPPARA" && destination === "S.S College") {
      return "Direct - 18 min";
    } else if (origin === "EDAVANNAPPARA" && destination === "AREEKODE") {
      return "Direct - 20 min";
    } else if (origin === "AREEKODE" && destination === "S.S College") {
      return "Direct - 2 min";
    } else if (origin === "AREEKODE" && destination === "EDAVANNAPPARA") {
      return "Direct - 20 min";
    }
    return "Route info unavailable";
  };
  
  return (
    <SafeAreaView className="flex-1">
      <StatusBar barStyle="light-content" backgroundColor="#000" />
      <ImageBackground
        source={{ uri: 'https://images.unsplash.com/photo-1741016825495-1faf2afc19d6?q=80&w=1888&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D' }}
        className="flex-1"
      >
        <LinearGradient
          colors={['rgba(0,0,0,0.7)', 'rgba(20,20,40,0.9)']}
          className="flex-1 px-5 pt-5"
        >
          <View className="flex-row justify-between pb-5">
            <Text className="font-bold text-3xl text-white">BusTime</Text>
            <Text className="text-base text-white bg-black/30 px-3 py-1.5 rounded-16">{currentTime}</Text>
          </View>
          
          <View className="bg-white/5 rounded-lg p-4 mb-4">
            <View className="mb-3">
              <Text className="text-sm text-gray-400 mb-2">From</Text>
              <ScrollView horizontal showsHorizontalScrollIndicator={false}>
                {locations.map((loc) => (
                  <TouchableOpacity
                    key={`origin-${loc}`}
                    className={`px-4 py-2 mr-2 rounded-lg  ${origin === loc ? 'bg-[#3f51b5]' : 'bg-white/10'}`}
                    onPress={() => handleOriginChange(loc)}
                  >
                    <Text className={`text-white  ${origin === loc ? 'font-bold' : 'font-medium'}`}>
                      {loc}
                    </Text>
                  </TouchableOpacity>
                ))}
              </ScrollView>
            </View>
            
            <TouchableOpacity 
              className="self-center bg-white/10 rounded-lg w-10 h-10 justify-center items-center my-1.5"
              onPress={() => {
                const temp = origin;
                setOrigin(destination);
                setDestination(temp);
              }}
            >
              <Ionicons name="swap-vertical" size={24} color="#fff" />
            </TouchableOpacity>
            
            <View className="mb-3">
              <Text className="text-sm text-gray-400 mb-2">To</Text>
              <ScrollView horizontal showsHorizontalScrollIndicator={false}>
                {locations.map((loc) => (
                  <TouchableOpacity
                    key={`dest-${loc}`}
                    className={`px-4 py-2 mr-2 rounded-lg  ${destination === loc ? 'bg-[#3f51b5]' : `${loc === origin ? 'bg-white/5' : 'bg-white/10'}`}`}
                    onPress={() => handleDestinationChange(loc)}
                    disabled={loc === origin}
                  >
                    <Text className={` ${destination === loc ? 'font-bold' : ' font-medium'} ${loc === origin ? 'text-white/30' : 'text-white'}`}>
                      {loc}
                    </Text>
                  </TouchableOpacity>
                ))}
              </ScrollView>
            </View>
          </View>
          
          <View className="bg-[#3f51b5]/30 rounded-lg p-4 mb-4">
            <Text className="text-base text-gray-400 mb-2">Next Bus</Text>
            {nextBus ? (
              <>
                <View className="flex-row items-baseline mb-3">
                  <Text className="text-[32px] font-bold text-white">{nextBus.time}</Text>
                  {nextBus.tomorrow && (
                    <Text className="text-xs text-orange-500 ml-2 px-2 py-0.5 bg-orange-500/20 rounded">Tomorrow</Text>
                  )}
                </View>
                
                <View className="flex-row justify-between bg-black/20 rounded-lg p-2">
                  <View className="flex-row items-center">
                    <Ionicons name="time-outline" size={20} color="#fff" />
                    <Text className="text-white ml-1">
                      {formatTimeRemaining(nextBus.minutes)} remaining
                    </Text>
                  </View>
                  
                  <View className="flex-row items-center">
                    <Ionicons name="git-network-outline" size={20} color="#fff" />
                    <Text className="text-white ml-1">{getRouteInfo()}</Text>
                  </View>
                </View>
              </>
            ) : (
              <Text className="text-white text-base text-center my-4">No bus schedule available for this route</Text>
            )}
          </View>
          
          <View className="flex-1 bg-white/5 rounded-lg p-4 mb-10">
            <Text className="text-base text-gray-400 mb-3">Today's Schedule</Text>
            {busSchedules[origin] && busSchedules[origin][destination] && busSchedules[origin][destination].length > 0 ? (
              <ScrollView className="flex-1">
                {busSchedules[origin][destination].map((time, index) => {
                  const isPassed = timeToMinutes(time) < timeToMinutes(currentTime);
                  const isNext = nextBus && time === nextBus.time;
                  
                  return (
                    <View 
                      key={index} 
                      className={`flex-row justify-between items-center py-2.5 border-b border-white/5 ${isPassed ? 'opacity-50' : ''} ${isNext ? 'bg-[#3f51b5]/20 rounded-lg px-2' : ''}`}
                    >
                      <Text className={`text-white text-base ${isPassed ? 'line-through' : ''} ${isNext ? 'font-bold' : ''}`}>
                        {time}
                      </Text>
                      
                      {isNext && (
                        <View className="bg-[#3f51b5] px-2 py-0.5 rounded">
                          <Text className="text-white text-xs font-bold">NEXT</Text>
                        </View>
                      )}
                    </View>
                  );
                })}
              </ScrollView>
            ) : (
              <Text className="text-white text-base text-center my-4">No schedule available for this route</Text>
            )}
          </View>
        </LinearGradient>
      </ImageBackground>
    </SafeAreaView>
  );
}
```


After applying the changes recreate project_snapshot.txt only for new files and files with changes, each time improve modularity of the program by introducing new component files (only on modified or new files), don't modify system files like pubspec, if we need new packages, or file path cahnges, removal etc, give the command for bash


Throughly check for ui sizing errors before writing the code