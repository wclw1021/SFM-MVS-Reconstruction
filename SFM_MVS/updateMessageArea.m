function updateMessageArea(app, message)
    currentText = app.UserData.messageArea.Value;
    currentText{end+1} = message;
    app.UserData.messageArea.Value = currentText;
    drawnow;
end