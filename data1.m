% --- CONFIGURATION ---
channelID = 2978406;
readAPIKey = 'UNGVRSJEQP64TY9N';
folderPath = 'C:\Users\ALAMAT\MATLAB Drive\HeartRateBackup';

% Email alert settings
setpref('Internet','SMTP_Server','smtp.gmail.com');
setpref('Internet','E_mail','mustafa97jabbar@gmail.com');
setpref('Internet','SMTP_Username','mustafa97jabbar@gmail.com');
setpref('Internet','SMTP_Password','ybch bmkv bpvv hsoe');

props = java.lang.System.getProperties;
props.setProperty('mail.smtp.auth','true');
props.setProperty('mail.smtp.socketFactory.class','javax.net.ssl.SSLSocketFactory');
props.setProperty('mail.smtp.socketFactory.port','465');
props.setProperty('mail.smtp.port','465');

% Ensure folder exists
if ~isfolder(folderPath)
    mkdir(folderPath);
end

dataFile = fullfile(folderPath, 'heart_rate_history.mat');
csvFile  = fullfile(folderPath, 'heart_rate_history.csv');

% --- LOOP TO LOG EVERY 10 MINUTES ---
disp("📡 Starting heart rate logger...");

while true
    try
        % Read data from ThingSpeak
        rawTT = thingSpeakRead(channelID, ...
            'Fields', [1, 2, 4], ...
            'NumPoints', 500, ...
            'ReadKey', readAPIKey, ...
            'OutputFormat', 'timetable');

        if ~isempty(rawTT) && width(rawTT) >= 3
            % Clean and rename
            T = rawTT(:, 1:3);
            T.Properties.VariableNames = {'BPM', 'ActivityCode', 'Alert'};
            T = rmmissing(T); % Remove missing values

            % Convert to table and format
            data = timetable2table(T, 'ConvertRowTimes', true);
            data.Properties.VariableNames{1} = 'Timestamp';
            data = sortrows(data, 'Timestamp');

            % Convert if needed
            if iscell(data.ActivityCode)
                data.ActivityCode = str2double(string(data.ActivityCode));
            end
            if iscell(data.Alert)
                data.Alert = str2double(string(data.Alert));
            end

            % Add activity and alert labels
            activityText = repmat("Unknown", height(data), 1);
            activityText(data.ActivityCode == 1) = "Rest";
            activityText(data.ActivityCode == 2) = "Work";
            activityText(data.ActivityCode == 3) = "Exercise";
            data.Activity = activityText;

            alertText = repmat("Unknown", height(data), 1);
            alertText(data.Alert == 1) = "Alert";
            alertText(data.Alert == 0) = "Normal";
            data.AlertStatus = alertText;

            % Remove numeric columns and format time
            data.ActivityCode = [];
            data.Alert = [];
            data.Timestamp = datestr(data.Timestamp, 'yyyy-mm-dd HH:MM:SS');

            % Save the data
            save(dataFile, 'data');
            writetable(data, csvFile);

            % === SEPARATE ACTIVITY & ALERT BAR CHARTS SECTION ===

            validData = data(~strcmp(data.Activity, "Unknown") & ~strcmp(data.AlertStatus, "Unknown"), :);

            if ~isempty(validData)
                % ===== Activity Chart =====
                activityTypes = categorical(validData.Activity);
                [uniqueActivities, ~, idxAct] = unique(activityTypes);
                activityCounts = accumarray(idxAct, 1);
                activityPercents = (activityCounts / sum(activityCounts)) * 100;

                figure(1); clf;
                bar(activityCounts);
                set(gca, 'XTickLabel', cellstr(uniqueActivities));
                xlabel('Activity Type');
                ylabel('Count');
                title('📊 Activity Frequency and Percentages');
                grid on;
                xt = get(gca, 'XTick');
                for i = 1:length(activityCounts)
                    text(xt(i), activityCounts(i) + 0.5, ...
                        sprintf('%.1f%%', activityPercents(i)), ...
                        'HorizontalAlignment', 'center', 'FontSize', 10);
                end
                activityChartFile = fullfile(folderPath, 'activity_chart.png');
                saveas(gcf, activityChartFile);

                % ===== Alert Chart =====
                alertTypes = categorical(validData.AlertStatus);
                [uniqueAlerts, ~, idxAlert] = unique(alertTypes);
                alertCounts = accumarray(idxAlert, 1);
                alertPercents = (alertCounts / sum(alertCounts)) * 100;

                figure(2); clf;
                bar(alertCounts);
                set(gca, 'XTickLabel', cellstr(uniqueAlerts));
                xlabel('Alert Status');
                ylabel('Count');
                title('⚠️ Alert Frequency and Percentages');
                grid on;
                xt2 = get(gca, 'XTick');
                for i = 1:length(alertCounts)
                    text(xt2(i), alertCounts(i) + 0.5, ...
                        sprintf('%.1f%%', alertPercents(i)), ...
                        'HorizontalAlignment', 'center', 'FontSize', 10);
                end
                alertChartFile = fullfile(folderPath, 'alert_chart.png');
                saveas(gcf, alertChartFile);
            else
                warning('⚠️ No valid data for charts.');
            end

            % Check for alert in latest record
            lastEntry = data(end, :);
            if strcmp(lastEntry.AlertStatus, "Alert")
                try
                    sendmail('mustafa97jabbar@gmail.com', ...
                        '⚠️ Heart Rate Alert', ...
                        ['High BPM detected: ', num2str(lastEntry.BPM), ...
                        ' at ', char(lastEntry.Timestamp)]);
                    disp('✔️ Email alert sent.');
                catch err
                    disp(['❌ Email alert failed: ', err.message]);
                end
            end

            fprintf("✅ Data processed and charts saved at %s\n", datestr(now));
        else
            warning("⚠️ No data returned from ThingSpeak.");
        end

    catch ME
        fprintf("❌ Error occurred: %s\n", ME.message);
    end

    pause(600);  % Wait 10 minutes
end
