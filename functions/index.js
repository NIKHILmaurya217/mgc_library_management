const { onRequest } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

// SCRIPT_URL equivalent
exports.exec = onRequest({ cors: true, maxInstances: 5 }, async (req, res) => {
  const uid = req.query.uid;
  const mode = req.query.mode;
  let ts = req.query.ts; // timestamp

  if (!uid) {
    return res.status(400).json({ status: "error", message: "Missing uid" });
  }

  // Create Date object from timestamp OR use current server time
  const scanTime = ts ? new Date(ts) : new Date();
  const timeString = scanTime.toLocaleTimeString('en-US', { hour12: false });

  try {
    // 1. Enrollment Mode
    if (mode === "enroll") {
      const studentQuery = await db.collection("students").where("uid", "==", uid).limit(1).get();
      
      if (!studentQuery.empty) {
        return res.json({ status: "already", message: "UID is already enrolled" });
      }

      // Create a stub student record for the admin to fill out later in the Web App
      await db.collection("students").add({
        uid: uid,
        name: "New Student " + uid.substring(0, 4),
        roll: "NEW-" + Date.now().toString().substring(8),
        className: "Pending",
        phone: "",
        status: "Left", // Default initial status
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });

      return res.json({ status: "enrolled", message: "UID enrolled successfully" });
    }

    // 2. Attendance Scan Mode
    const studentQuery = await db.collection("students").where("uid", "==", uid).limit(1).get();
    
    if (studentQuery.empty) {
      return res.json({ status: "unknown", message: "UID not found" });
    }

    const studentDoc = studentQuery.docs[0];
    const studentData = studentDoc.data();
    const currentStatus = studentData.status || "Left";

    let newStatus, actionType;
    let duration = "";

    if (currentStatus === "Left" || currentStatus === "Outside") {
      newStatus = "Inside";
      actionType = "Entry";
      
      // Update student status & record last entry time
      await studentDoc.ref.update({
        status: newStatus,
        lastEntryTime: admin.firestore.Timestamp.fromDate(scanTime)
      });

    } else {
      newStatus = "Left";
      actionType = "Exit";
      
      // Calculate duration if lastEntryTime exists
      if (studentData.lastEntryTime) {
        const lastEntry = studentData.lastEntryTime.toDate();
        const diffMs = scanTime.getTime() - lastEntry.getTime();
        const diffMins = Math.floor(diffMs / 60000);
        const diffHrs = Math.floor(diffMins / 60);
        const minsLeft = diffMins % 60;
        
        if (diffHrs > 0) {
          duration = `${diffHrs}h ${minsLeft}m`;
        } else {
          duration = `${minsLeft}m`;
        }
      }

      await studentDoc.ref.update({
        status: newStatus
      });
    }

    // Log the attendance event
    await db.collection("attendance").add({
      studentId: studentDoc.id,
      studentName: studentData.name,
      studentRoll: studentData.roll,
      uid: uid,
      action: actionType, // "Entry" or "Exit"
      timestamp: admin.firestore.Timestamp.fromDate(scanTime),
      duration: duration
    });

    // Return the exact JSON structure the ESP32 expects
    return res.json({
      status: "success",
      name: studentData.name,
      type: actionType,
      time: timeString,
      duration: duration
    });

  } catch (error) {
    console.error("Error processing scan:", error);
    return res.status(500).json({ status: "error", message: error.message });
  }
});
