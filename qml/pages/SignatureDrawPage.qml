import QtQuick 2.7
import QtQuick.Layouts 1.3
import Lomiri.Components 1.3
import UTControls 1.0

Page {
    id: page
    title: i18n.tr("Draw your signature")

    signal drawingSaved(string dataUri)
    signal drawingCanceled()

    header: PageHeader {
        id: header
        title: page.title
    }

    // Locking Screen.orientationUpdateMask to landscape only restricts which sensor
    // readings the app will FOLLOW - it can't force the physical device to actually
    // be held in landscape. Doing that here left a window where the app had already
    // switched to a landscape-sized canvas while the phone was still physically in
    // portrait, so touch coordinates landed in the wrong place until the user
    // rotated for real. Letting the page follow whatever orientation the app is
    // already in (same as the rest of the app) avoids that mismatch entirely; the
    // hint below just suggests rotating for more room instead of forcing it.
    ColumnLayout {
        anchors { fill: parent; topMargin: header.height; margins: units.gu(1) }
        spacing: units.gu(1)

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            // Just a visible backdrop while drawing - not part of the exported
            // image. The Canvas below never fills its own background, so its
            // pixel buffer (what toDataURL() actually exports) stays transparent
            // everywhere except the drawn strokes.
            color: "white"
            radius: units.gu(0.5)
            border.width: 1
            border.color: theme.palette.normal.base

            Canvas {
                id: canvas
                anchors.fill: parent
                property bool hasStrokes: false
                property var lastPoint: null
                property bool clearedByResize: false

                // A Canvas's backing store is raster, tied to its item size - on
                // resize (e.g. an orientation change), Qt stretches the existing
                // content to the new size non-uniformly rather than redrawing it,
                // which distorts the signature. Nothing here keeps the stroke path
                // data needed to redraw it correctly at a new size, so the safe
                // choice is to clear rather than let it come out warped.
                onWidthChanged: canvas.handleResize()
                onHeightChanged: canvas.handleResize()

                function handleResize() {
                    if (!hasStrokes) {
                        return
                    }
                    clearCanvas()
                    canvas.clearedByResize = true
                }

                function clearCanvas() {
                    var ctx = getContext("2d")
                    ctx.reset()
                    requestPaint()
                    canvas.hasStrokes = false
                }

                function strokeTo(x, y) {
                    var ctx = getContext("2d")
                    ctx.lineWidth = units.gu(0.35)
                    ctx.lineCap = "round"
                    ctx.strokeStyle = "black"
                    ctx.beginPath()
                    ctx.moveTo(canvas.lastPoint.x, canvas.lastPoint.y)
                    ctx.lineTo(x, y)
                    ctx.stroke()
                    canvas.lastPoint = Qt.point(x, y)
                    canvas.hasStrokes = true
                    // Drawing commands issued outside onPaint don't repaint the
                    // item on their own - without this, nothing appears on screen
                    // until something unrelated forces a repaint.
                    requestPaint()
                }

                MouseArea {
                    anchors.fill: parent
                    onPressed: {
                        canvas.clearedByResize = false
                        canvas.lastPoint = Qt.point(mouse.x, mouse.y)
                    }
                    onPositionChanged: if (pressed) canvas.strokeTo(mouse.x, mouse.y)
                }
            }
        }

        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: canvas.clearedByResize
                ? i18n.tr("The drawing area changed size, so it was cleared - please sign again.")
                : i18n.tr("Sign with your finger or a stylus, then tap Save. Rotating your device gives more room to draw.")
            textSize: Label.Small
            color: canvas.clearedByResize ? "#b37a2a" : theme.palette.normal.backgroundText
            opacity: canvas.clearedByResize ? 1.0 : 0.72
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: units.gu(1)

            AppButton {
                Layout.fillWidth: true
                text: i18n.tr("Cancel")
                variant: "normal"
                onClicked: page.drawingCanceled()
            }
            AppButton {
                Layout.fillWidth: true
                text: i18n.tr("Clear")
                variant: "normal"
                enabled: canvas.hasStrokes
                onClicked: canvas.clearCanvas()
            }
            AppButton {
                Layout.fillWidth: true
                text: i18n.tr("Save")
                variant: "primary"
                enabled: canvas.hasStrokes
                onClicked: page.drawingSaved(canvas.toDataURL("image/png"))
            }
        }
    }
}
