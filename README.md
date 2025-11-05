

This service is a work-around for the memory leak in Kokoro-82M TTS https://github.com/hexgrad/kokoro/issues/152 which affects KokoroDoki, my favorite implementation of Kokoro. https://github.com/eel-brah/kokorodoki

Normal memory usage on my system is about 1.6GB. It grows from there with usage.

The service checks RAM used by the Kokorodoki service and when the RAM is over a certain threshold, it restarts the service. 

It won't restart the service if the last message is "Started new playback thread", because it wouldn't be nice to restart when we're in the middle of saying something.

So the idea here is to wait for an idle period and then restart the service. For the use case where you're intermittently having text read to you, this should work well. If you're reading something voluminous then, quite possibly, the RAM usage is going to keep growing beyond the threshold and this isn't going to be much help

#Requirements

Kokorodoki https://github.com/eel-brah/kokorodoki

#Installation

As root...

Copy kokorodoki_monitor.sh to /usr/local/bin 

chmod +x  usr/local/bin/kokorodoki_monitor.sh

Copy kokorodoki-monitor.service to /etc/systemd/system

Copy koko-monitor.timer to /etc/systemd/system

systemctl daemon-reload

systemctl enable --now kokodoki-monitor.timer

You may want to edit the default memory threshold (THRESHOLD_GB=4) in kokorodoki_monitor.sh
